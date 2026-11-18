import SwiftData
import SwiftUI

struct RootView: View {
    @State private var catalogStore: CatalogStore = CatalogStore()
    @State private var library: LibraryStore = LibraryStore()
    @State private var localLibrary: LocalLibrary
    @State private var presetStore: PresetStore
    @State private var player: PlayerController
    @State private var navigation: AppNavigation = AppNavigation()
    @State private var receivedPreset: SlowPreset?
    @State private var openError: String?

    init(container: ModelContainer) {
        _localLibrary = State(initialValue: LocalLibrary(context: container.mainContext))
        _presetStore = State(initialValue: PresetStore(context: container.mainContext))
        _player = State(initialValue: PlayerController(engine: AudioEngineService(), nowPlaying: NowPlayingService()))
    }

    var body: some View {
        ThemedRoot {
            content
                .environment(catalogStore)
                .environment(library)
                .environment(localLibrary)
                .environment(presetStore)
                .environment(player)
                .environment(navigation)
                .task {
                    if catalogStore.state == .loading { load() }
                }
                .onOpenURL { url in openPresetFile(url) }
                .alert(
                    "Preset recibido",
                    isPresented: Binding(get: { receivedPreset != nil }, set: { if !$0 { receivedPreset = nil } }),
                    presenting: receivedPreset
                ) { preset in
                    let reference = PresetTrackReference(title: preset.trackTitle, artist: preset.trackArtist, duration: preset.trackDuration)
                    if let track = localLibrary.match(reference) {
                        Button("Aplicar ahora") {
                            player.apply(preset.communityPreset, to: track)
                            player.isNowPlayingPresented = true
                        }
                    } else {
                        Button("Importar la canción") { navigation.openImport() }
                    }
                    Button("Cerrar", role: .cancel) {}
                } message: { preset in
                    let summary: String = SlowModeFormat.summary(tempo: preset.tempo, pitch: preset.pitch, reverb: preset.reverb) ?? "Original"
                    let hasTrack: Bool = localLibrary.match(PresetTrackReference(title: preset.trackTitle, artist: preset.trackArtist, duration: preset.trackDuration)) != nil
                    Text("«\(preset.name)» (\(summary)) para «\(preset.trackTitle)» de \(preset.trackArtist). Está guardado en Biblioteca → Presets guardados." + (hasTrack ? "" : " Aún no tienes esta canción en tu biblioteca."))
                }
                .alert(
                    "No se pudo abrir el preset",
                    isPresented: Binding(get: { openError != nil }, set: { if !$0 { openError = nil } })
                ) {
                    Button("Aceptar", role: .cancel) {}
                } message: {
                    Text(openError ?? "")
                }
        }
    }

    /// Abre un archivo `.slowpreset` recibido (AirDrop, Mensajes, Archivos…): lo guarda y ofrece aplicarlo.
    private func openPresetFile(_ url: URL) {
        guard url.pathExtension.lowercased() == PresetFile.fileExtension else { return }
        let hasAccess: Bool = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let data: Data = try Data(contentsOf: url)
            let file: PresetFile = try PresetFile.decode(data)
            let preset: SlowPreset = presetStore.saveReceived(file)
            // iOS deja una copia en Documents/Inbox: ya no hace falta.
            if url.path.contains("/Inbox/") { try? FileManager.default.removeItem(at: url) }
            player.isNowPlayingPresented = false
            receivedPreset = preset
        } catch let error as PresetFileError {
            openError = error.message
        } catch {
            openError = PresetFileError.invalid.message
        }
    }

    @ViewBuilder
    private var content: some View {
        switch catalogStore.state {
        case .loading:
            ProgressView("Cargando tu música…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AmbientBackground())
        case .failed(let message):
            ContentUnavailableView {
                Label("No se pudo cargar la música", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Reintentar") { load() }
                    .buttonStyle(.glass)
            }
            .background(AmbientBackground())
        case .loaded:
            MainTabView()
        }
    }

    private func load() {
        let localLibrary: LocalLibrary = localLibrary
        player.fileURLProvider = { track in localLibrary.fileURL(for: track.id) }
        player.artworkProvider = { track in localLibrary.artwork(for: track.id) }
        player.listeningObserver = { tick in localLibrary.handle(tick) }
        catalogStore.load()

        // El minirreproductor arranca con tu música (si aún no has importado nada, queda vacío).
        player.prepareIfIdle(with: localLibrary.catalogTracks, source: "Tu música")
    }
}

enum AppInfo {
    static let name: String = "Slow Mode"
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}
