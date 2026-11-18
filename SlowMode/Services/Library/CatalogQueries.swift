import Foundation

struct CatalogAlbum: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let artistId: String
    let artist: String
    let trackCount: Int
}

extension SampleCatalog {
    static let empty: SampleCatalog = SampleCatalog(
        artists: [],
        tracks: [],
        presets: [],
        mixes: [],
        listeners: [],
        home: HomeStats(
            songsPlayed: 0,
            streakDays: 0,
            trackCount: 0,
            topGenres: [],
            discover: DiscoverMap(centerArtistId: "", similar: [])
        )
    )

    func track(id: String) -> CatalogTrack? {
        tracks.first { $0.id == id }
    }

    /// Colores (hex) de la portada/avatar de un artista. Los originales propios usan crema.
    func artistColorHex(for artistId: String) -> (background: String, foreground: String) {
        if let artist = self.artist(id: artistId) {
            return (artist.color, artist.onColor)
        }
        return ("#F4F1EA", "#101014")
    }

    /// Copia local de la pista de un preset: por id o por título + artista + duración (±3 s).
    func localTrack(for preset: CommunityPreset) -> CatalogTrack? {
        if let trackId = preset.trackId, let found = self.track(id: trackId) {
            return found
        }
        return tracks.first { track in
            Self.sameText(track.title, preset.track.title)
                && Self.sameText(track.artist, preset.track.artist)
                && abs(track.duration - preset.track.duration) <= 3
        }
    }

    /// Presets que encajan con una pista (de ejemplo o importada): por id o por título + artista + duración (±3 s).
    func presets(forTrack track: CatalogTrack) -> [CommunityPreset] {
        presets.filter { preset in
            preset.trackId == track.id
                || (Self.sameText(preset.track.title, track.title)
                    && Self.sameText(preset.track.artist, track.artist)
                    && abs(preset.track.duration - track.duration) <= 3)
        }
    }

    /// Álbumes derivados de las pistas, en el orden en que aparecen.
    var albums: [CatalogAlbum] {
        var seen: [String: Int] = [:]
        var result: [CatalogAlbum] = []
        for track in tracks {
            let key: String = track.artistId + "|" + track.album
            if let index = seen[key] {
                let old: CatalogAlbum = result[index]
                result[index] = CatalogAlbum(id: old.id, title: old.title, artistId: old.artistId, artist: old.artist, trackCount: old.trackCount + 1)
            } else {
                seen[key] = result.count
                result.append(CatalogAlbum(id: key, title: track.album, artistId: track.artistId, artist: track.artist, trackCount: 1))
            }
        }
        return result
    }

    /// Géneros de los artistas, sin repetir, en orden de aparición.
    var genres: [String] {
        var seen: Set<String> = []
        return artists.compactMap { artist in seen.insert(artist.genre).inserted ? artist.genre : nil }
    }

    static func sameText(_ a: String, _ b: String) -> Bool {
        a.compare(b, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }
}

enum ArtistSort: String, CaseIterable, Sendable {
    case plays
    case name

    var title: String {
        switch self {
        case .plays: return "Reproducciones"
        case .name: return "A-Z"
        }
    }
}

enum ArtistDirectory {
    /// Filtra por género (`nil` = todos) y ordena.
    static func artists(_ artists: [CatalogArtist], genre: String?, sort: ArtistSort) -> [CatalogArtist] {
        let filtered: [CatalogArtist] = artists.filter { genre == nil || $0.genre == genre }
        switch sort {
        case .plays:
            return filtered.sorted { $0.plays > $1.plays }
        case .name:
            return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }
}
