import Foundation
import SceneKit
import UniformTypeIdentifiers

enum WardrobeSlot: String, Codable, CaseIterable, Identifiable {
    case hair = "Cabello", face = "Rostro", top = "Torso", pants = "Pantalón", shoes = "Zapatos"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .hair: return "person.crop.circle"
        case .face: return "face.smiling"
        case .top: return "tshirt"
        case .pants: return "figure.stand"
        case .shoes: return "shoeprints.fill"
        }
    }

    init?(folder: String) {
        switch folder {
        case "hair": self = .hair
        case "faces": self = .face
        case "shirt": self = .top
        case "pants": self = .pants
        case "shoes": self = .shoes
        default: return nil
        }
    }
}

struct ImportedAsset: Identifiable, Codable {
    var id = UUID()
    let name: String
    let kind: String
    let size: Int
    let version: String?
    let pieces: [WardrobeSlot: [String]]
    let entries: [String]
    let slot: WardrobeSlot?
    let localName: String

    var isModel: Bool { kind != "UnityFS" }
}

struct SavedLook: Identifiable, Codable {
    var id = UUID()
    let name: String
    let base: UUID
    let pieces: [WardrobeSlot: UUID]
}

enum ImportError: LocalizedError {
    case unsupportedFile, unsupportedBundle, invalidBundle, invalidModel, tooLarge

    var errorDescription: String? {
        switch self {
        case .unsupportedFile: return "Elige un paquete UnityFS o un modelo SCN, DAE, OBJ o USDZ."
        case .unsupportedBundle: return "Esta versión o compresión de UnityFS aún no es compatible."
        case .invalidBundle: return "El paquete UnityFS está incompleto o dañado."
        case .invalidModel: return "No se pudo cargar el modelo 3D. Prueba con un archivo USDZ que incluya las texturas."
        case .tooLarge: return "El archivo supera el tamaño que admite el importador."
        }
    }
}

enum AssetImport {
    static let types: [UTType] = [.data, .item, .archive, .content]
    private static let modelExtensions = ["scn", "dae", "obj", "usdz"]

    static func directory() throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        let folder = root.appendingPathComponent("PantherImports", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func url(for asset: ImportedAsset) throws -> URL {
        try directory().appendingPathComponent(asset.localName)
    }

    static func read(_ url: URL, slot: WardrobeSlot?) throws -> ImportedAsset {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var result: Result<ImportedAsset, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { readable in
            result = Result { try copyAndInspect(readable, name: url.lastPathComponent, slot: slot) }
        }
        if let error = coordinationError { throw error }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
    }

    static func scene(_ url: URL) throws -> SCNScene {
        guard let scene = try? SCNScene(url: url, options: [.checkConsistency: true]) else {
            throw ImportError.invalidModel
        }
        var hasGeometry = false
        scene.rootNode.enumerateChildNodes { node, stop in
            if node.geometry != nil {
                hasGeometry = true
                stop.pointee = true
            }
        }
        guard hasGeometry else { throw ImportError.invalidModel }
        return scene
    }

    private static func copyAndInspect(_ url: URL, name: String, slot: WardrobeSlot?) throws -> ImportedAsset {
        let attributes = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard attributes.isRegularFile == true, let size = attributes.fileSize else { throw ImportError.unsupportedFile }
        guard size <= 256 * 1024 * 1024 else { throw ImportError.tooLarge }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let prefix = try file.read(upToCount: 8) ?? Data()
        let isBundle = prefix.starts(with: "UnityFS\0".utf8)
        let ext = (name as NSString).pathExtension.lowercased()
        guard isBundle || modelExtensions.contains(ext) else { throw ImportError.unsupportedFile }
        let localName = UUID().uuidString + "." + (isBundle ? "bundle" : ext)
        let local = try directory().appendingPathComponent(localName)
        try FileManager.default.copyItem(at: url, to: local)
        do {
            if isBundle {
                let bundle = try UnityBundle(data: Data(contentsOf: local, options: .mappedIfSafe))
                return ImportedAsset(name: name, kind: "UnityFS", size: size, version: bundle.version,
                                     pieces: bundle.pieces, entries: bundle.directory, slot: nil, localName: localName)
            }
            _ = try scene(local)
            return ImportedAsset(name: name, kind: ext.uppercased(), size: size, version: nil,
                                 pieces: [:], entries: [], slot: slot, localName: localName)
        } catch {
            try? FileManager.default.removeItem(at: local)
            throw error
        }
    }
}
