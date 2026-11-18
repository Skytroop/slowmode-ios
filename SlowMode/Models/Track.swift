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
    /// Género leído de las etiquetas del archivo o puesto a mano. Vacío = sin género.
    var genre: String = ""
    /// `true` cuando ya se intentó leer el género del archivo (para no repetirlo).
    var genreChecked: Bool = false
    var lastPlayedAt: Date? = nil

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String,
        duration: Double,
        fileName: String,
        origin: TrackOrigin,
        artworkData: Data?,
        genre: String = "",
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
        self.genre = genre
        self.genreChecked = true
        self.lastPlayedAt = nil
    }

    var origin: TrackOrigin { TrackOrigin(rawValue: originRaw) ?? .localFile }
}

enum LocalTrackID {
    static let prefix: String = "local-"
    static let artistPrefix: String = "local-artist:"

    static func catalogId(for id: UUID) -> String { prefix + id.uuidString }

    static func uuid(from catalogId: String) -> UUID? {
        guard catalogId.hasPrefix(prefix), !catalogId.hasPrefix(artistPrefix) else { return nil }
        return UUID(uuidString: String(catalogId.dropFirst(prefix.count)))
    }

    static func artistId(for artist: String) -> String {
        artistPrefix + artist.lowercased()
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

/// Playlist del usuario. Guarda los ids de las pistas en orden.
@Model
final class Playlist {
    @Attribute(.unique) var id: UUID
    var name: String
    var trackIDs: [UUID]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, trackIDs: [UUID] = [], createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.trackIDs = trackIDs
        self.createdAt = createdAt
    }
}

/// Una escucha que cuenta (≥ 30 s o la mitad de la canción). De aquí salen las estadísticas de Inicio.
@Model
final class PlayEvent {
    @Attribute(.unique) var id: UUID
    var trackID: UUID
    var date: Date
    /// Segundos reales escuchados en esa sesión.
    var seconds: Double
    var tempo: Double
    /// Copia del artista y el género del momento (las estadísticas sobreviven si se borra la pista).
    var artist: String
    var genre: String

    init(id: UUID = UUID(), trackID: UUID, date: Date, seconds: Double, tempo: Double, artist: String, genre: String) {
        self.id = id
        self.trackID = trackID
        self.date = date
        self.seconds = seconds
        self.tempo = tempo
        self.artist = artist
        self.genre = genre
    }
}
