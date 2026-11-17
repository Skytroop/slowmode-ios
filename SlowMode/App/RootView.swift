import SwiftUI

struct RootView: View {
    @State private var catalogStore: CatalogStore = CatalogStore()
    @State private var library: LibraryStore = LibraryStore()
    @State private var player: PlayerController = PlayerController()
    @State private var navigation: AppNavigation = AppNavigation()

    var body: some View {
        ThemedRoot {
            content
                .environment(catalogStore)
                .environment(library)
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
        catalogStore.load()
        player.prepareIfIdle(with: catalogStore.catalog)
    }
}

enum AppInfo {
    static let name: String = "Slow Mode"
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}

#Preview {
    RootView()
}
