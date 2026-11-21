import Foundation

struct UnityBundle {
    let version: String
    let pieces: [WardrobeSlot: [String]]
    let directory: [String]

    private static let limit = 64 * 1024 * 1024

    init(data: Data) throws {
        var header = BundleReader(data: data)
        guard try header.string() == "UnityFS" else { throw ImportError.invalidBundle }
        let revision = try header.number(4)
        guard (6...8).contains(revision) else { throw ImportError.unsupportedBundle }
        _ = try header.string()
        version = try header.string()
        let length = try header.number(8)
        let packedSize = try header.number(4)
        let expandedSize = try header.number(4)
        let flags = try header.number(4)
        if revision >= 7 { header.align() }
        let metadataAtEnd = flags & 0x80 != 0
        guard length <= data.count, length >= header.position,
              packedSize <= length - header.position else { throw ImportError.invalidBundle }
        let metadataOffset = metadataAtEnd ? length - packedSize : header.position
        var table = BundleReader(data: try Self.decode(
            data[metadataOffset..<(metadataOffset + packedSize)], size: expandedSize, method: flags & 63
        ), position: 16)
        let count = try table.number(4)
        guard count <= 50_000 else { throw ImportError.tooLarge }
        var blocks: [(size: Int, packed: Int, method: Int)] = []
        for _ in 0..<count {
            blocks.append((try table.number(4), try table.number(4), try table.number(2) & 63))
        }

        let entryCount = try table.number(4)
        guard entryCount <= 50_000 else { throw ImportError.tooLarge }
        var names: [String] = []
        var serialized: [Range<Int>] = []
        for _ in 0..<entryCount {
            let start = try table.number(8)
            let size = try table.number(8)
            _ = try table.number(4)
            let name = try table.string()
            names.append(name)
            if name.hasPrefix("CAB-"), !name.contains("."), size > 0 {
                guard start <= Self.limit, size <= Self.limit - start else { throw ImportError.tooLarge }
                serialized.append(start..<(start + size))
            }
        }
        directory = names
        guard let last = serialized.map(\.upperBound).max() else {
            pieces = [:]
            return
        }

        var packedOffset = metadataAtEnd ? header.position : metadataOffset + packedSize
        if flags & 0x200 != 0 { packedOffset = (packedOffset + 15) & ~15 }
        let packedEnd = metadataAtEnd ? metadataOffset : length
        var payload = Data()
        for block in blocks {
            guard packedOffset <= packedEnd, block.packed <= packedEnd - packedOffset else {
                throw ImportError.invalidBundle
            }
            let next = packedOffset + block.packed
            let decoded = try Self.decode(data[packedOffset..<next], size: block.size, method: block.method)
            payload.append(decoded.prefix(last - payload.count))
            if payload.count == last { break }
            packedOffset = next
        }
        guard payload.count == last else { throw ImportError.invalidBundle }

        let pattern = try NSRegularExpression(
            pattern: #"assets/[a-z0-9_./-]{1,480}/wardrobe_(hair|faces|shirt|pants|shoes)/[a-z0-9_./-]{1,350}\.asset"#,
            options: [.caseInsensitive]
        )
        var bySlot: [WardrobeSlot: Set<String>] = [:]
        for range in serialized {
            let content = String(decoding: payload[range], as: UTF8.self)
            for match in pattern.matches(in: content, range: NSRange(content.startIndex..., in: content)) {
                guard let full = Range(match.range(at: 0), in: content),
                      let folder = Range(match.range(at: 1), in: content),
                      let slot = WardrobeSlot(folder: content[folder].lowercased()),
                      let filename = content[full].split(separator: "/").last else { continue }
                bySlot[slot, default: []].insert(String(filename.dropLast(".asset".count)))
            }
        }
        pieces = bySlot.mapValues { $0.sorted() }
    }

    private static func decode(_ source: Data, size: Int, method: Int) throws -> Data {
        guard size <= limit else { throw ImportError.tooLarge }
        if method == 0 {
            guard source.count == size else { throw ImportError.invalidBundle }
            return source
        }
        guard method == 1 || method == 2 || method == 3 else { throw ImportError.unsupportedBundle }
        guard size > 0, !source.isEmpty else { throw ImportError.invalidBundle }
        var decoded = Data(count: size)
        let success = decoded.withUnsafeMutableBytes { output in
            source.withUnsafeBytes { input in
                if method == 1 {
                    return panther_lzma(input.bindMemory(to: UInt8.self).baseAddress, source.count,
                                        output.bindMemory(to: UInt8.self).baseAddress, size)
                }
                return panther_lz4(input.bindMemory(to: UInt8.self).baseAddress, source.count,
                                   output.bindMemory(to: UInt8.self).baseAddress, size)
            }
        }
        guard success == 1 else { throw ImportError.invalidBundle }
        return decoded
    }
}

private struct BundleReader {
    let data: Data
    var position = 0

    mutating func align() { position = (position + 15) & ~15 }

    mutating func number(_ width: Int) throws -> Int {
        guard position <= data.count, width <= data.count - position else { throw ImportError.invalidBundle }
        var result: UInt64 = 0
        let start = data.startIndex + position
        for byte in data[start..<(start + width)] { result = (result << 8) | UInt64(byte) }
        position += width
        guard let value = Int(exactly: result) else { throw ImportError.invalidBundle }
        return value
    }

    mutating func string() throws -> String {
        guard position < data.count else { throw ImportError.invalidBundle }
        let start = data.startIndex + position
        let limit = start + min(1024, data.count - position)
        guard let end = data[start..<limit].firstIndex(of: 0),
              let text = String(data: data[start..<end], encoding: .utf8) else {
            throw ImportError.invalidBundle
        }
        position += end - start + 1
        return text
    }
}
