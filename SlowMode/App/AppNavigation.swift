import SwiftUI
import Observation

enum AppTab: Hashable {
    case home, search, library, community
}

enum AppRoute: Hashable {
    case artist(String)
    case allPresets
}

/// Pestaña activa y hojas globales.
@MainActor
@Observable
final class AppNavigation {
    var selectedTab: AppTab = .home
    var isImportPresented: Bool = false

    init() {}

    /// Lleva a Biblioteca y abre la hoja de importar.
    func openImport() {
        selectedTab = .library
        isImportPresented = true
    }
}

extension View {
    /// Destinos de push compartidos por los `NavigationStack` de todas las pestañas.
    func appDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .artist(let id):
                ArtistView(artistId: id)
            case .allPresets:
                AllPresetsView()
            }
        }
    }
}
