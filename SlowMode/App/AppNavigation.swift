import SwiftUI
import Observation

enum AppTab: Hashable {
    case home, search, library, community
}

enum AppRoute: Hashable {
    case artist(String)
    case playlist(UUID)
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
            case .playlist(let id):
                PlaylistView(playlistID: id)
            case .allPresets:
                AllPresetsView()
            }
        }
    }
}

extension View {
    /// Aviso cuando un preset es de una canción que no tienes, con opción de importarla.
    func missingTrackAlert(_ preset: Binding<CommunityPreset?>) -> some View {
        modifier(MissingTrackAlert(preset: preset))
    }
}

private struct MissingTrackAlert: ViewModifier {
    @Binding var preset: CommunityPreset?
    @Environment(AppNavigation.self) private var navigation: AppNavigation
    @Environment(PlayerController.self) private var player: PlayerController

    func body(content: Content) -> some View {
        content.alert(
            "Necesitas esta pista en tu biblioteca",
            isPresented: Binding(get: { preset != nil }, set: { if !$0 { preset = nil } }),
            presenting: preset
        ) { _ in
            Button("Importar") {
                player.isNowPlayingPresented = false
                navigation.openImport()
            }
            Button("Cancelar", role: .cancel) {}
        } message: { preset in
            Text("Importa «\(preset.track.title)» de \(preset.track.artist) para aplicarle este preset. Slow Mode nunca descarga ni comparte audio.")
        }
    }
}
