import Foundation

/// Origen de una pista: importada desde Archivos o subida como original propio.
enum TrackOrigin: String, Codable, Sendable, CaseIterable {
    case localFile
    case originalUpload
}

/// Artista del catálogo de ejemplo (misma forma que el backend final).
struct CatalogArtist: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let genre: String
    let plays: Int
    let rank: Int
    /// Color de fondo del avatar (hex `#RRGGBB`).
    let color: String
    /// Color del texto sobre `color`.
    let onColor: String

    var initials: String { Initials.fromName(name) }
}

struct CatalogTrack: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let artistId: String
    let title: String
    let artist: String
    let album: String
    /// Duración en segundos.
    let duration: Int
    let plays: Int
    let origin: TrackOrigin
}

/// Pista a la que se aplica un preset. Se empareja con la copia local por título, artista y duración aproximada.
struct PresetTrackReference: Codable, Hashable, Sendable {
    let title: String
    let artist: String
    let duration: Int
}

struct PresetCreator: Codable, Hashable, Sendable {
    let handle: String
    let color: String
    let onColor: String

    var initials: String { Initials.fromHandle(handle) }
}

/// Preset de Slow Mode compartido por la comunidad. Solo ajustes, nunca audio.
struct CommunityPreset: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// Velocidad, 0.5–1.5.
    let tempo: Double
    /// Semitonos, −12…+12.
    let pitch: Int
    /// Reverb, 0–100 %.
    let reverb: Int
    let linked: Bool
    let track: PresetTrackReference
    /// Solo en los datos de ejemplo: pista del catálogo a la que apunta.
    let trackId: String?
    let artistId: String?
    let creator: PresetCreator
    let uses: Int
    let likes: Int
    let createdAt: Date
}

enum MixStyle: String, Codable, Sendable {
    case periwinkle, pink, sand, dark
}

/// Mezcla original subida por un usuario.
struct CatalogMix: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let creator: String
    let minutes: Int
    let style: MixStyle
    let tags: [String]
    let previewTrackId: String?
}

struct CatalogListener: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// Afinidad 0–100.
    let affinity: Int
    let color: String
    let onColor: String

    var initials: String { Initials.fromName(name) }
}

struct GenreShare: Codable, Hashable, Sendable {
    let genre: String
    let percent: Int
}

struct SimilarArtist: Codable, Hashable, Sendable {
    let artistId: String
    let affinity: Int
}

struct DiscoverMap: Codable, Hashable, Sendable {
    let centerArtistId: String
    let similar: [SimilarArtist]
}

struct HomeStats: Codable, Hashable, Sendable {
    let songsPlayed: Int
    let streakDays: Int
    let trackCount: Int
    let topGenres: [GenreShare]
    let discover: DiscoverMap
}

enum Initials {
    /// "Luna Vale" → "LV"
    static func fromName(_ name: String) -> String {
        let letters: [String] = name.split(separator: " ").compactMap { word in word.first.map { String($0) } }
        return letters.prefix(2).joined().uppercased()
    }

    /// "tape.hiss" → "TA", "3amdrive" → "3A"
    static func fromHandle(_ handle: String) -> String {
        let cleaned: String = handle.lowercased().filter { ch in ch.isASCII && (ch.isLetter || ch.isNumber) }
        return String(cleaned.prefix(2)).uppercased()
    }
}
