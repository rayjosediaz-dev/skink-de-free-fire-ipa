import SwiftUI
import SceneKit

@main struct PantherFFSkinViewerApp: App {
    var body: some Scene { WindowGroup { MainView() } }
}

private enum Screen: String, CaseIterable {
    case viewer = "Visor", wardrobe = "Vestidor", files = "Archivos"

    var symbol: String {
        switch self {
        case .viewer: return "cube"
        case .wardrobe: return "tshirt"
        case .files: return "folder"
        }
    }
}

struct MainView: View {
    @State private var screen = Screen.viewer
    @State private var studioEnabled = true
    @State private var characterIndex = 0
    @State private var hairIndex = 0
    @State private var topIndex = 0
    @State private var pantsIndex = 0
    @State private var shoesIndex = 0
    @State private var exportURL: URL?
    @State private var showingShare = false
    @State private var showingImporter = false
    @State private var importSlot: WardrobeSlot?
    @State private var importing = false
    @State private var assets: [ImportedAsset] = []
    @State private var activeAsset: ImportedAsset?
    @State private var selectedSlot = WardrobeSlot.top
    @State private var equipped: [WardrobeSlot: UUID] = [:]
    @State private var preview: SCNScene?
    @State private var errorMessage: String?
    @State private var lookName = ""
    @State private var savedLooks: [SavedLook] = []
    @AppStorage("panther.selectedAsset") private var lastAsset = ""

    private let accent = Color(red: 0.67, green: 0.57, blue: 1)
    private let background = Color(red: 0.03, green: 0.04, blue: 0.07)
    private let panel = Color(red: 0.07, green: 0.085, blue: 0.135)

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch screen {
                    case .viewer: viewer
                    case .wardrobe: wardrobe
                    case .files: files
                    }
                }
                .frame(maxWidth: 660)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
            tabBar
        }
        .background(background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .tint(accent)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: AssetImport.types,
                      allowsMultipleSelection: false, onCompletion: handleSelection)
        .alert("Panther FF", isPresented: Binding(get: { errorMessage != nil },
                                                  set: { if !$0 { errorMessage = nil } })) {
            Button("Aceptar", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showingShare) {
            if let exportURL { PantherShareSheet(url: exportURL) }
        }
        .onAppear {
            restoreLibrary()
            if activeAsset == nil { refreshStudio() }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 48, height: 48)
                .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 15))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Panther FF").font(.system(.title2, design: .rounded).bold())
                Text("Skin Viewer").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if screen != .viewer {
                Button { chooseFile() } label: {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.headline)
                        .frame(width: 48, height: 48)
                        .background(panel, in: RoundedRectangle(cornerRadius: 15))
                }
                .disabled(importing)
                .accessibilityLabel("Importar desde Archivos")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
    }

    private var viewer: some View {
        Group {
            ZStack {
                RoundedRectangle(cornerRadius: 26)
                    .fill(RadialGradient(colors: [accent.opacity(0.23), panel], center: .center,
                                         startRadius: 10, endRadius: 220))
                if let preview {
                    SceneView(scene: preview, options: [.allowsCameraControl, .autoenablesDefaultLighting])
                        .id(ObjectIdentifier(preview))
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .accessibilityLabel("Vista interactiva del modelo 3D")
                } else {
                    stageGrid
                    VStack(spacing: 12) {
                        Image(systemName: activeAsset == nil ? "cube.transparent" : "shippingbox")
                            .font(.system(size: 70, weight: .ultraLight))
                            .foregroundStyle(accent)
                            .shadow(color: accent.opacity(0.45), radius: 20)
                            .accessibilityHidden(true)
                        Text(activeAsset == nil ? "Visor 3D" : "Paquete UnityFS")
                            .font(.system(.title2, design: .rounded).bold())
                        Text(activeAsset == nil ? "Abre un modelo para verlo aquí." : "Consulta los recursos del paquete en el Vestidor.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                }
            }
            .frame(height: 350)
            .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(accent.opacity(0.22)))
            if studioEnabled { studioControls }
            importButton("Importar desde Archivos", symbol: "tray.and.arrow.down") { chooseFile() }
            if let activeAsset {
                VStack(alignment: .leading, spacing: 6) {
                    assetSummary(activeAsset)
                    if !activeAsset.isModel {
                        Button("Ver prendas detectadas") { screen = .wardrobe }
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(panel, in: RoundedRectangle(cornerRadius: 16))
            } else {
                Label("UnityFS, SCN, DAE, OBJ y USDZ", systemImage: "doc")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(panel, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var stageGrid: some View {
        Canvas { context, size in
            let horizon = size.height * 0.70
            let center = size.width * 0.5
            var grid = Path()
            for column in -5...5 {
                let step = CGFloat(column) * size.width / 8
                grid.move(to: CGPoint(x: center + step * 0.24, y: horizon))
                grid.addLine(to: CGPoint(x: center + step, y: size.height))
            }
            for fraction in [0.08, 0.17, 0.30, 0.48, 0.71, 0.98] {
                let y = horizon + (size.height - horizon) * CGFloat(fraction)
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(grid, with: .linearGradient(
                Gradient(colors: [accent.opacity(0.02), accent.opacity(0.30)]),
                startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: size.height)
            ), lineWidth: 0.65)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .accessibilityHidden(true)
    }

    private var wardrobe: some View {
        Group {
            Text("Vestidor").font(.system(.largeTitle, design: .rounded).bold())
            if studioEnabled { studioWardrobe }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(WardrobeSlot.allCases) { slot in
                        Button { selectedSlot = slot } label: {
                            VStack(spacing: 7) {
                                Image(systemName: slot.symbol).imageScale(.large)
                                Text(slot.rawValue).font(.caption.weight(.semibold))
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 62)
                            .foregroundStyle(slot == selectedSlot ? background : Color.white)
                            .background(slot == selectedSlot ? accent : panel,
                                        in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(slot == selectedSlot ? .isSelected : [])
                    }
                }
            }
            if let activeAsset, !activeAsset.isModel {
                Text("Recursos de \(selectedSlot.rawValue.lowercased())").font(.headline)
                let names = activeAsset.pieces[selectedSlot] ?? []
                if names.isEmpty {
                    Text("No se encontraron recursos de esta categoría.").foregroundStyle(.secondary)
                }
                ForEach(names, id: \.self) { name in
                    Label(name, systemImage: selectedSlot.symbol)
                        .font(.footnote.monospaced())
                        .padding(13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(panel, in: RoundedRectangle(cornerRadius: 14))
                }
            }

            Text("Prendas importadas").font(.headline)
            if activeAsset?.isModel != true {
                Text("Abre un modelo base en el Visor para probar prendas 3D compatibles.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(assets.filter { $0.slot == selectedSlot }) { piece in
                Button {
                    if equipped[selectedSlot] == piece.id { equipped.removeValue(forKey: selectedSlot) }
                    else { equipped[selectedSlot] = piece.id }
                    rebuildScene()
                    if preview != nil { screen = .viewer }
                } label: {
                    HStack {
                        assetSummary(piece)
                        Spacer()
                        Image(systemName: equipped[selectedSlot] == piece.id ? "checkmark.circle.fill" : "plus.circle")
                            .imageScale(.large).foregroundStyle(accent)
                    }
                    .padding(14)
                    .background(panel, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(activeAsset?.isModel != true)
            }
            importButton("Importar prenda", symbol: "plus") { chooseFile(slot: selectedSlot) }

            Text("Conjuntos").font(.headline).padding(.top, 8)
            if activeAsset?.isModel == true, let base = activeAsset?.id {
                HStack {
                    TextField("Nombre del conjunto", text: $lookName)
                        .textFieldStyle(.roundedBorder)
                    Button("Guardar") {
                        savedLooks.append(SavedLook(name: lookName.trimmingCharacters(in: .whitespacesAndNewlines),
                                                   base: base, pieces: equipped))
                        persist(savedLooks, key: "panther.looks")
                        lookName = ""
                    }
                    .buttonStyle(.bordered)
                    .disabled(lookName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            ForEach(savedLooks) { look in
                Button {
                    guard let base = assets.first(where: { $0.id == look.base }) else { return }
                    select(base, pieces: look.pieces)
                } label: {
                    Label(look.name, systemImage: "bookmark")
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(panel, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            let legacyNames = UserDefaults.standard.stringArray(forKey: "looks") ?? []
            if !legacyNames.isEmpty {
                Text("Nombres guardados anteriormente").font(.footnote).foregroundStyle(.secondary)
                ForEach(Array(legacyNames.enumerated()), id: \.offset) { entry in Text(entry.element) }
            }
        }
    }

    private var files: some View {
        Group {
            Text("Archivos").font(.system(.largeTitle, design: .rounded).bold())
            if assets.isEmpty {
                Text("Tus archivos importados aparecerán aquí.").foregroundStyle(.secondary)
            }
            ForEach(assets) { asset in
                Button { select(asset) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: asset.slot?.symbol ?? (asset.isModel ? "cube" : "shippingbox"))
                            .font(.title3).foregroundStyle(accent)
                            .frame(width: 36)
                        assetSummary(asset)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(panel, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func assetSummary(_ asset: ImportedAsset) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(asset.name).font(.subheadline.weight(.semibold)).lineLimit(2)
            Text([asset.slot?.rawValue, asset.kind, asset.version.map { "Unity \($0)" },
                  ByteCountFormatter.string(fromByteCount: Int64(asset.size), countStyle: .file)]
                .compactMap { $0 }.joined(separator: "  ·  "))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Screen.allCases, id: \.self) { tab in
                Button { screen = tab } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbol).font(.system(size: 20, weight: .medium))
                        Text(tab.rawValue).font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(screen == tab ? accent : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(screen == tab ? .isSelected : [])
            }
        }
        .background(panel.ignoresSafeArea(edges: .bottom))
    }

    private func importButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if importing { ProgressView().tint(background) }
                else { Image(systemName: symbol) }
                Text(importing ? "Importando…" : title).fontWeight(.bold)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(background)
            .background(accent, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(importing)
    }

    private func chooseFile(slot: WardrobeSlot? = nil) {
        importSlot = slot
        showingImporter = true
    }

    private func handleSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            let failure = error as NSError
            if failure.domain != NSCocoaErrorDomain || failure.code != NSUserCancelledError {
                errorMessage = error.localizedDescription
            }
        case .success(let urls):
            guard let url = urls.first else { return }
            let slot = importSlot
            importing = true
            Task { @MainActor in
                defer { importing = false }
                do {
                    let asset = try await Task.detached(priority: .userInitiated) {
                        try AssetImport.read(url, slot: slot)
                    }.value
                    assets.insert(asset, at: 0)
                    persist(assets, key: "panther.assets")
                    if asset.slot == nil { select(asset) }
                    else { screen = .wardrobe }
                } catch { errorMessage = error.localizedDescription }
            }
        }
    }

    private func select(_ asset: ImportedAsset, pieces: [WardrobeSlot: UUID] = [:]) {
        studioEnabled = false
        activeAsset = asset
        lastAsset = asset.id.uuidString
        equipped = pieces
        rebuildScene()
        screen = .viewer
    }

    private func refreshStudio() {
        studioEnabled = true
        preview = PantherStudio.make(character: characterIndex, hair: hairIndex, top: topIndex, pants: pantsIndex, shoes: shoesIndex)
    }

    private var studioControls: some View {
        VStack(spacing: 10) {
            Text("Personajes originales incluidos · gira el modelo con el dedo")
                .font(.footnote).foregroundStyle(.secondary)
            HStack {
                Button("Personaje aleatorio") {
                    characterIndex = Int.random(in: 0..<PantherStudio.skinColors.count)
                    hairIndex = Int.random(in: 0..<PantherStudio.hairColors.count)
                    topIndex = Int.random(in: 0..<PantherStudio.clothColors.count)
                    pantsIndex = Int.random(in: 0..<PantherStudio.clothColors.count)
                    shoesIndex = Int.random(in: 0..<PantherStudio.clothColors.count)
                    refreshStudio()
                }
                .buttonStyle(.borderedProminent)
                Button("Exportar .scn") {
                    guard let preview else { return }
                    do {
                        exportURL = try PantherStudio.export(preview)
                        showingShare = true
                    } catch { errorMessage = error.localizedDescription }
                }
                .buttonStyle(.bordered)
            }
            Button("Volver al personaje incluido") { refreshStudio() }
                .font(.footnote)
        }
    }

    private var studioWardrobe: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ropa incluida · diseños originales").font(.headline)
            Text("Selecciona colores y estilos para vestir al personaje 3D. No son modelos oficiales de Free Fire.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(WardrobeSlot.allCases) { slot in
                VStack(alignment: .leading, spacing: 6) {
                    Text(slot.rawValue).font(.subheadline.weight(.semibold))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 9) {
                            ForEach(0..<(slot == .hair ? PantherStudio.hairColors.count : slot == .face ? PantherStudio.skinColors.count : PantherStudio.clothColors.count), id: \.self) { index in
                                Button {
                                    switch slot {
                                    case .hair: hairIndex = index
                                    case .face: characterIndex = index
                                    case .top: topIndex = index
                                    case .pants: pantsIndex = index
                                    case .shoes: shoesIndex = index
                                    }
                                    refreshStudio()
                                } label: {
                                    Circle()
                                        .fill(Color(uiColor: slot == .hair ? PantherStudio.hairColors[index] : slot == .face ? PantherStudio.skinColors[index] : PantherStudio.clothColors[index]))
                                        .frame(width: 40, height: 40)
                                        .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1))
                                }
                                .accessibilityLabel("\(slot.rawValue) opción \(index + 1)")
                            }
                        }
                    }
                }
            }
            Button("Ver personaje vestido") { screen = .viewer }
                .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .background(panel, in: RoundedRectangle(cornerRadius: 16))
    }

    private func rebuildScene() {
        guard let activeAsset, activeAsset.isModel else {
            preview = nil
            return
        }
        do {
            let scene = try AssetImport.scene(AssetImport.url(for: activeAsset))
            for slot in WardrobeSlot.allCases {
                guard let id = equipped[slot], id != activeAsset.id,
                      let asset = assets.first(where: { $0.id == id && $0.slot == slot }) else { continue }
                let piece = try AssetImport.scene(AssetImport.url(for: asset))
                for child in piece.rootNode.childNodes { scene.rootNode.addChildNode(child) }
            }
            preview = scene
        } catch {
            preview = nil
            errorMessage = error.localizedDescription
        }
    }

    private func restoreLibrary() {
        let decoder = JSONDecoder()
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "panther.assets"),
           let imported = try? decoder.decode([ImportedAsset].self, from: data) { assets = imported }
        if let data = defaults.data(forKey: "panther.looks"),
           let looks = try? decoder.decode([SavedLook].self, from: data) { savedLooks = looks }
        if activeAsset == nil, let last = assets.first(where: { $0.id.uuidString == lastAsset }) { select(last) }
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            UserDefaults.standard.set(data, forKey: key)
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct PantherShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
