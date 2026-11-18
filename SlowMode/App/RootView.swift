import SwiftData
import SwiftUI

struct RootView: View {
    @State private var catalogStore: CatalogStore = CatalogStore()
    @State private var library: LibraryStore = LibraryStore()
    @State private var localLibrary: LocalLibrary
    @State private var presetStore: PresetStore
    @State private var player: PlayerController
    @State private var navigation: AppNavigation = AppNavigation()

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
        catalogStore.load()

        // Si tienes música importada, el minirreproductor arranca con ella; si no, con los datos de ejemplo.
        if !localLibrary.tracks.isEmpty {
            player.prepareIfIdle(with: localLibrary.catalogTracks, source: "Tu música")
        } else {
            let catalog: SampleCatalog = catalogStore.catalog
            let artistId: String = catalog.home.discover.centerArtistId
            player.prepareIfIdle(
                with: catalog.tracks(byArtist: artistId),
                source: catalog.artist(id: artistId)?.name ?? ""
            )
        }
    }
}

enum AppInfo {
    static let name: String = "Slow Mode"
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}
