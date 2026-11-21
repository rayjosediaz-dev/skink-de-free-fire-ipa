import SwiftUI
import UniformTypeIdentifiers
import SceneKit

@main struct PantherFFSkinViewerApp: App {
    var body: some Scene { WindowGroup { MainView() } }
}

struct ImportedAsset: Identifiable, Codable {
    var id = UUID()
    let name: String
    let format: String
    let size: Int
    let unityVersion: String?
}

enum WardrobeSlot: String, CaseIterable, Identifiable {
    case hair = "Cabello", face = "Máscara", top = "Camisa", pants = "Pantalón", shoes = "Zapatos"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .hair: return "person.crop.circle"
        case .face: return "theatermasks"
        case .top: return "tshirt"
        case .pants: return "figure.stand"
        case .shoes: return "shoeprints.fill"
        }
    }
}

struct MainView: View {
    @State private var showImporter = false
    @State private var assets: [ImportedAsset] = []
    @State private var selectedSlot: WardrobeSlot = .top
    @State private var message = "Importa un archivo para examinar su formato."
    @State private var previewModel: URL?
    @State private var lookName = "Mi conjunto"
    @State private var savedLooks: [String] = []
    private let accent = Color(red: 0.13, green: 0.64, blue: 1)
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        Image(systemName: "pawprint.fill").foregroundColor(accent)
                        VStack(alignment: .leading) {
                            Text("PANTHER FF").font(.title2.bold())
                            Text("SKIN VIEWER").font(.caption).tracking(3).foregroundColor(accent)
                        }
                        Spacer()
                        Text("iOS").font(.caption).foregroundColor(.gray)
                    }
                    .padding(.top, 12)
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.06, green: 0.10, blue: 0.18))
                        if let url = previewModel {
                            ModelPreview(url: url).padding(8)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "person.crop.rectangle.stack").font(.system(size: 65)).foregroundColor(accent)
                                Text("Visor 3D").font(.title3.bold())
                                Text("Importa un modelo .scn o .dae para verlo aquí. Los UnityFS se inspeccionan, pero aún no se renderizan.")
                                    .font(.caption).multilineTextAlignment(.center).foregroundColor(.gray).padding(.horizontal, 30)
                            }.padding(.bottom, 45)
                        }
                        Text(previewModel == nil ? "SIN MODELO CARGADO" : "MODELO 3D CARGADO")
                            .font(.caption2.bold()).foregroundColor(accent).padding(10)
                            .frame(maxWidth: .infinity).background(.black.opacity(0.6))
                    }
                    .frame(height: 300).clipShape(RoundedRectangle(cornerRadius: 20))
                    Button { showImporter = true } label: {
                        Label("Importar archivo", systemImage: "square.and.arrow.down")
                            .font(.headline).frame(maxWidth: .infinity).padding(14)
                    }
                    .buttonStyle(.borderedProminent).tint(accent)
                    Text(message).font(.caption).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("VESTIDOR").font(.headline)
                        Text("Categorías preparadas para prendas importadas. No incluye skins oficiales preinstaladas.")
                            .font(.caption).foregroundColor(.gray)
                        ForEach(WardrobeSlot.allCases) { slot in
                            Button { selectedSlot = slot } label: {
                                HStack {
                                    Image(systemName: slot.symbol).frame(width: 25)
                                    Text(slot.rawValue)
                                    Spacer()
                                    Text("Sin prendas").font(.caption).foregroundColor(.gray)
                                    Image(systemName: "chevron.right")
                                }.padding(12).background(selectedSlot == slot ? accent.opacity(0.2) : Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain)
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("GUARDAR CONJUNTO").font(.headline)
                        TextField("Nombre del conjunto", text: $lookName).textFieldStyle(.roundedBorder)
                        Button("Guardar nombre del conjunto") {
                            let name = lookName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !name.isEmpty { savedLooks.append(name); UserDefaults.standard.set(savedLooks, forKey: "looks") }
                        }.buttonStyle(.bordered)
                        ForEach(savedLooks, id: \.self) { Text("• \($0)").font(.subheadline) }
                        Text("En esta versión se guardan nombres, no combinaciones 3D.").font(.caption).foregroundColor(.gray)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ARCHIVOS IMPORTADOS").font(.headline)
                        if assets.isEmpty { Text("Todavía no hay archivos.").foregroundColor(.gray) }
                        ForEach(assets) { asset in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(asset.name).font(.subheadline.bold()).lineLimit(2)
                                Text("\(asset.format) • \(asset.size) bytes" + (asset.unityVersion.map { " • Unity \($0)" } ?? ""))
                                    .font(.caption).foregroundColor(.gray)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                                .background(Color.white.opacity(0.06)).cornerRadius(8)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.padding(16)
            }
            .background(Color(red: 0.025, green: 0.04, blue: 0.08)).foregroundColor(.white)
            .navigationBarHidden(true)
            .onAppear { savedLooks = UserDefaults.standard.stringArray(forKey: "looks") ?? [] }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls): if let url = urls.first { inspect(url) }
                case .failure(let error): message = "No se pudo abrir: \(error.localizedDescription)"
                }
            }
        }.navigationViewStyle(.stack)
    }
    private func inspect(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let prefix = data.prefix(128)
            let isUnity = prefix.starts(with: Data("UnityFS".utf8))
            var version: String? = nil
            if isUnity {
                let fields = prefix.split(separator: 0)
                if fields.count >= 3 { version = String(data: fields[2], encoding: .utf8) }
            }
            let ext = url.pathExtension.lowercased()
            let isModel = ["scn", "dae"].contains(ext)
            if isModel {
                let target = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
                try data.write(to: target)
                previewModel = target
                message = "Modelo 3D importado. Puedes girarlo y ampliarlo."
            } else if isUnity {
                previewModel = nil
                message = "UnityFS detectado. La lectura de mallas, prendas y texturas requiere un decodificador adicional."
            } else {
                previewModel = nil
                message = "Archivo importado, pero no es un modelo 3D compatible ni un UnityFS reconocido."
            }
            assets.insert(ImportedAsset(name: url.lastPathComponent, format: isUnity ? "UnityFS" : (isModel ? "Modelo 3D" : "Desconocido"), size: data.count, unityVersion: version), at: 0)
        } catch { message = "Error leyendo archivo: \(error.localizedDescription)" }
    }
}

struct ModelPreview: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor.clear
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.scene = try? SCNScene(url: url, options: nil)
        return view
    }
    func updateUIView(_ view: SCNView, context: Context) {
        view.scene = try? SCNScene(url: url, options: nil)
    }
}
