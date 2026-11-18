import Foundation
import SwiftData

/// Pista importada por el usuario. El audio vive en `Application Support/Tracks/<fileName>`.
@Model
final class Track {
    @Attribute(.unique) var id: UUID
    var title: String
    var artist: String
    var album: String
    /// Duración en segundos.
    var duration: Double
    /// Nombre del archivo dentro de la carpeta de pistas.
    var fileName: String
    var originRaw: String
    @Attribute(.externalStorage) var artworkData: Data?
    var plays: Int
    var isLiked: Bool
    var importedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String,
        duration: Double,
        fileName: String,
        origin: TrackOrigin,
        artworkData: Data?,
        importedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.fileName = fileName
        self.originRaw = origin.rawValue
        self.artworkData = artworkData
        self.plays = 0
        self.isLiked = false
        self.importedAt = importedAt
    }

    var origin: TrackOrigin { TrackOrigin(rawValue: originRaw) ?? .localFile }
}

enum LocalTrackID {
    static let prefix: String = "local-"

    static func catalogId(for id: UUID) -> String { prefix + id.uuidString }

    static func uuid(from catalogId: String) -> UUID? {
        guard catalogId.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(catalogId.dropFirst(prefix.count)))
    }

    static func artistId(for artist: String) -> String {
        "local-artist:" + artist.lowercased()
    }
}

extension Track {
    /// Vista de la pista con la forma que usan las pantallas.
    var catalogTrack: CatalogTrack {
        CatalogTrack(
            id: LocalTrackID.catalogId(for: id),
            artistId: LocalTrackID.artistId(for: artist),
            title: title,
            artist: artist,
            album: album,
            duration: Int(duration.rounded()),
            plays: plays,
            origin: origin
        )
    }
}
