import Foundation
import Observation

struct UserPlaylist: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var trackIds: [String]
    let createdAt: Date
}

/// Me gusta, playlists y seguidos. En memoria hasta la Fase 3 (SwiftData).
@MainActor
@Observable
final class LibraryStore {
    private(set) var likedTrackIds: Set<String>
    private(set) var likedPresetIds: Set<String>
    private(set) var followedListenerIds: Set<String>
    private(set) var playlists: [UserPlaylist]

    init(
        likedTrackIds: Set<String> = ["me-0", "a0-0", "a1-0", "a2-1", "a3-2", "a4-0"],
        likedPresetIds: Set<String> = ["a0-0-v0", "a1-0-v1"],
        followedListenerIds: Set<String> = [],
        playlists: [UserPlaylist] = LibraryStore.samplePlaylists
    ) {
        self.likedTrackIds = likedTrackIds
        self.likedPresetIds = likedPresetIds
        self.followedListenerIds = followedListenerIds
        self.playlists = playlists
    }

    nonisolated static let samplePlaylists: [UserPlaylist] = [
        UserPlaylist(id: UUID(), name: "Camino al trabajo", trackIds: ["a1-0", "a0-1", "a2-0", "a3-1"], createdAt: .now),
        UserPlaylist(id: UUID(), name: "Gimnasio, a tope", trackIds: ["a5-1", "a2-3", "a8-2"], createdAt: .now),
    ]

    func isLiked(trackId: String) -> Bool { likedTrackIds.contains(trackId) }

    func toggleLike(trackId: String) {
        if likedTrackIds.contains(trackId) { likedTrackIds.remove(trackId) } else { likedTrackIds.insert(trackId) }
    }

    func isLiked(presetId: String) -> Bool { likedPresetIds.contains(presetId) }

    func toggleLike(presetId: String) {
        if likedPresetIds.contains(presetId) { likedPresetIds.remove(presetId) } else { likedPresetIds.insert(presetId) }
    }

    func isFollowing(_ listenerId: String) -> Bool { followedListenerIds.contains(listenerId) }

    func toggleFollow(_ listenerId: String) {
        if followedListenerIds.contains(listenerId) { followedListenerIds.remove(listenerId) } else { followedListenerIds.insert(listenerId) }
    }

    /// Crea una playlist. Devuelve `nil` si el nombre está vacío.
    @discardableResult
    func createPlaylist(named name: String) -> UserPlaylist? {
        let trimmed: String = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let playlist = UserPlaylist(id: UUID(), name: trimmed, trackIds: [], createdAt: .now)
        playlists.append(playlist)
        return playlist
    }

    /// Añade una pista a una playlist (sin duplicados). Devuelve `false` si ya estaba o no existe.
    @discardableResult
    func add(trackId: String, toPlaylist playlistId: UUID) -> Bool {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return false }
        guard !playlists[index].trackIds.contains(trackId) else { return false }
        playlists[index].trackIds.append(trackId)
        return true
    }
}
