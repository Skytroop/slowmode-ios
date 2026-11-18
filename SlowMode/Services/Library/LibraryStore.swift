import Foundation
import Observation

/// Preferencias de comunidad: presets de otros con me gusta y oyentes que sigues.
/// Se guardan en `UserDefaults` hasta que exista el backend (Fase 5).
/// (Los me gusta de canciones y las playlists viven en `LocalLibrary`.)
@MainActor
@Observable
final class LibraryStore {
    private(set) var likedPresetIds: Set<String>
    private(set) var followedListenerIds: Set<String>

    @ObservationIgnored private let defaults: UserDefaults
    private static let likedPresetsKey: String = "likedPresetIds"
    private static let followedKey: String = "followedListenerIds"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        likedPresetIds = Set(defaults.stringArray(forKey: Self.likedPresetsKey) ?? [])
        followedListenerIds = Set(defaults.stringArray(forKey: Self.followedKey) ?? [])
    }

    func isLiked(presetId: String) -> Bool { likedPresetIds.contains(presetId) }

    func toggleLike(presetId: String) {
        if likedPresetIds.contains(presetId) { likedPresetIds.remove(presetId) } else { likedPresetIds.insert(presetId) }
        defaults.set(Array(likedPresetIds).sorted(), forKey: Self.likedPresetsKey)
    }

    func isFollowing(_ listenerId: String) -> Bool { followedListenerIds.contains(listenerId) }

    func toggleFollow(_ listenerId: String) {
        if followedListenerIds.contains(listenerId) { followedListenerIds.remove(listenerId) } else { followedListenerIds.insert(listenerId) }
        defaults.set(Array(followedListenerIds).sorted(), forKey: Self.followedKey)
    }
}
