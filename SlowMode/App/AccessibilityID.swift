import Foundation

/// Identificadores de accesibilidad, declarados una sola vez y compartidos con las pruebas de interfaz.
/// Formato: {área}_{pantalla}_{elemento}_{matiz}.
enum AccessibilityID {
    // Pantallas
    static let homeView: String = "home_screen_view"
    static let searchView: String = "search_screen_view"
    static let libraryView: String = "library_screen_view"
    static let communityView: String = "community_screen_view"
    static let artistView: String = "artist_screen_view"
    static let playlistView: String = "playlist_screen_view"
    static let nowPlayingView: String = "player_now_playing_view"

    // Minirreproductor
    static let miniPlayerOpen: String = "player_mini_open_button"
    static let miniPlayerPlayPause: String = "player_mini_play_pause_button"
    static let miniPlayerSpeed: String = "player_mini_speed_button"

    // Reproduciendo
    static let nowPlayingClose: String = "player_now_playing_close_button"
    static let nowPlayingPlayPause: String = "player_now_playing_play_pause_button"
    static let nowPlayingProgress: String = "player_now_playing_progress_slider"
    static let nowPlayingLoop: String = "player_now_playing_loop_button"
    static let nowPlayingQueue: String = "player_now_playing_queue_button"
    static let slowModeToggle: String = "player_slow_mode_toggle"
    static let slowModeExpand: String = "player_slow_mode_expand_button"
    static let slowModeSave: String = "player_slow_mode_save_button"

    // Biblioteca
    static let libraryImport: String = "library_screen_import_button"
    static let libraryCreatePlaylist: String = "library_screen_create_playlist_button"
}
