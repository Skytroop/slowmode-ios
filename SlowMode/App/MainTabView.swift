import SwiftUI

struct MainTabView: View {
    @Environment(AppNavigation.self) private var navigation: AppNavigation
    @Environment(PlayerController.self) private var player: PlayerController

    var body: some View {
        @Bindable var navigation = navigation
        @Bindable var player = player

        TabView(selection: $navigation.selectedTab) {
            Tab("Inicio", systemImage: "house", value: AppTab.home) {
                NavigationStack {
                    HomeView().appDestinations()
                }
            }
            Tab("Buscar", systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
                NavigationStack {
                    SearchView().appDestinations()
                }
            }
            Tab("Biblioteca", systemImage: "square.stack", value: AppTab.library) {
                NavigationStack {
                    LibraryView().appDestinations()
                }
            }
            Tab("Comunidad", systemImage: "person.2", value: AppTab.community) {
                NavigationStack {
                    CommunityView().appDestinations()
                }
            }
        }
        .tabViewBottomAccessory {
            MiniPlayerView()
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .fullScreenCover(isPresented: $player.isNowPlayingPresented) {
            NowPlayingView()
        }
        .alert(
            "No se pudo reproducir",
            isPresented: Binding(get: { player.playbackError != nil }, set: { if !$0 { player.dismissError() } })
        ) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(player.playbackError ?? "")
        }
    }
}
