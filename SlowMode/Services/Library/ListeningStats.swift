import Foundation

/// Lo que el reproductor informa cada cuarto de segundo mientras suena.
struct ListeningTick: Sendable, Equatable {
    /// Cambia cada vez que se carga una pista: separa una escucha de la siguiente.
    let sessionID: UUID
    let trackID: String
    /// Segundos reales transcurridos desde el tick anterior.
    let seconds: Double
    let tempo: Double
    let duration: Double
}

/// Decide cuándo una escucha cuenta: al llegar a 30 s o a la mitad de la canción (lo que antes ocurra).
struct ListeningTracker: Sendable {
    enum Update: Equatable, Sendable {
        case none
        /// Acaba de contar, con los segundos escuchados hasta ahora.
        case counted(seconds: Double)
        /// Ya contaba: suma más segundos a la escucha.
        case extended(seconds: Double)
    }

    private(set) var sessionID: UUID?
    private(set) var listened: Double = 0
    private(set) var hasCounted: Bool = false

    static func threshold(forDuration duration: Double) -> Double {
        guard duration > 0 else { return 30 }
        return min(30, duration / 2)
    }

    mutating func record(_ tick: ListeningTick) -> Update {
        if tick.sessionID != sessionID {
            sessionID = tick.sessionID
            listened = 0
            hasCounted = false
        }
        listened += tick.seconds
        if hasCounted { return .extended(seconds: tick.seconds) }
        if listened >= Self.threshold(forDuration: tick.duration) {
            hasCounted = true
            return .counted(seconds: listened)
        }
        return .none
    }
}

struct PlaySnapshot: Sendable {
    let date: Date
    let seconds: Double
    let genre: String
}

struct TrackSnapshot: Sendable {
    let artist: String
    let genre: String
    let plays: Int
}

/// Cálculos de Inicio a partir de tus escuchas y tus pistas.
enum ListeningStats {
    static let noGenre: String = "Sin género"

    /// Días seguidos con al menos una escucha, terminando hoy (o ayer, si hoy aún no has escuchado nada).
    static func streak(_ events: [PlaySnapshot], now: Date, calendar: Calendar = .current) -> Int {
        let days: Set<Date> = Set(events.map { calendar.startOfDay(for: $0.date) })
        let today: Date = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
        var day: Date
        if days.contains(today) {
            day = today
        } else if days.contains(yesterday) {
            day = yesterday
        } else {
            return 0
        }
        var count: Int = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// Porcentaje del tiempo escuchado por género (los `limit` primeros).
    static func topGenres(_ events: [PlaySnapshot], limit: Int = 4) -> [GenreShare] {
        var seconds: [String: Double] = [:]
        for event in events {
            let genre: String = event.genre.isEmpty ? noGenre : event.genre
            seconds[genre, default: 0] += max(0, event.seconds)
        }
        let total: Double = seconds.values.reduce(0, +)
        guard total > 0 else { return [] }
        return seconds
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(limit)
            .map { GenreShare(genre: $0.key, percent: Int(($0.value / total * 100).rounded())) }
    }

    /// Tus artistas a partir de tus pistas: género más frecuente, reproducciones sumadas y orden por escuchas.
    static func artists(from tracks: [TrackSnapshot]) -> [CatalogArtist] {
        var order: [String] = []
        var names: [String: String] = [:]
        var plays: [String: Int] = [:]
        var genres: [String: [String: Int]] = [:]
        for track in tracks {
            let key: String = track.artist.lowercased()
            if names[key] == nil {
                names[key] = track.artist
                order.append(key)
            }
            plays[key, default: 0] += track.plays
            if !track.genre.isEmpty {
                genres[key, default: [:]][track.genre, default: 0] += 1
            }
        }
        let sorted: [String] = order.sorted { a, b in
            let pa: Int = plays[a] ?? 0
            let pb: Int = plays[b] ?? 0
            return pa == pb ? (names[a] ?? a).localizedStandardCompare(names[b] ?? b) == .orderedAscending : pa > pb
        }
        return sorted.enumerated().map { index, key in
            let name: String = names[key] ?? key
            let genre: String = genres[key]?.max { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }?.key ?? noGenre
            let colors = ArtistPalette.colors(for: name)
            return CatalogArtist(
                id: LocalTrackID.artistId(for: name),
                name: name,
                genre: genre,
                plays: plays[key] ?? 0,
                rank: index + 1,
                color: colors.background,
                onColor: colors.foreground
            )
        }
    }

    /// Mapa "Descubre": el más escuchado en el centro y hasta 6 más; primero los de su mismo género.
    /// La afinidad combina género compartido y escuchas.
    static func discover(_ artists: [CatalogArtist]) -> DiscoverMap {
        guard let center = artists.first else { return DiscoverMap(centerArtistId: "", similar: []) }
        let maxPlays: Double = Double(max(center.plays, 1))
        let others: [CatalogArtist] = Array(artists.dropFirst())
        let ranked: [(CatalogArtist, Int)] = others.map { artist in
            let share: Double = min(1, Double(artist.plays) / maxPlays)
            let sameGenre: Bool = artist.genre == center.genre && artist.genre != noGenre
            let affinity: Int = Int(((sameGenre ? 60 : 30) + 39 * share).rounded())
            return (artist, affinity)
        }
        .sorted { $0.1 == $1.1 ? $0.0.rank < $1.0.rank : $0.1 > $1.1 }
        return DiscoverMap(
            centerArtistId: center.id,
            similar: ranked.prefix(6).map { SimilarArtist(artistId: $0.0.id, affinity: $0.1) }
        )
    }
}

/// Color estable para el avatar de un artista (mismo nombre ⇒ mismo color, en cualquier arranque).
enum ArtistPalette {
    private static let pairs: [(String, String)] = [
        ("#B9C8F2", "#101014"),
        ("#F1C4DF", "#101014"),
        ("#D2BDB8", "#101014"),
        ("#F4F1EA", "#101014"),
        ("#3A3F78", "#F4F4F5"),
        ("#2C2C34", "#F4F4F5"),
        ("#C5D1F6", "#101014"),
    ]

    static func colors(for name: String) -> (background: String, foreground: String) {
        let sum: Int = name.lowercased().unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
        let pair = pairs[sum % pairs.count]
        return (pair.0, pair.1)
    }
}

/// Normaliza el género de las etiquetas (ID3 usa códigos como "(13)").
enum GenreName {
    private static let id3: [String] = [
        "Blues", "Classic Rock", "Country", "Dance", "Disco", "Funk", "Grunge", "Hip-Hop", "Jazz", "Metal",
        "New Age", "Oldies", "Other", "Pop", "R&B", "Rap", "Reggae", "Rock", "Techno", "Industrial",
        "Alternative", "Ska", "Death Metal", "Pranks", "Soundtrack", "Euro-Techno", "Ambient", "Trip-Hop", "Vocal", "Jazz+Funk",
        "Fusion", "Trance", "Classical", "Instrumental", "Acid", "House", "Game", "Sound Clip", "Gospel", "Noise",
        "Alternative Rock", "Bass", "Soul", "Punk", "Space", "Meditative", "Instrumental Pop", "Instrumental Rock", "Ethnic", "Gothic",
        "Darkwave", "Techno-Industrial", "Electronic", "Pop-Folk", "Eurodance", "Dream", "Southern Rock", "Comedy", "Cult", "Gangsta",
        "Top 40", "Christian Rap", "Pop/Funk", "Jungle", "Native American", "Cabaret", "New Wave", "Psychedelic", "Rave", "Showtunes",
        "Trailer", "Lo-Fi", "Tribal", "Acid Punk", "Acid Jazz", "Polka", "Retro", "Musical", "Rock & Roll", "Hard Rock",
    ]

    /// Nombre del género ID3v1 por índice (0 = Blues).
    static func id3Name(_ index: Int) -> String? {
        id3.indices.contains(index) ? id3[index] : nil
    }

    /// "(13)" → "Pop", "(17)Rock" → "Rock", "13" → "Pop", "Indie" → "Indie", "" → nil
    static func normalize(_ raw: String) -> String? {
        let text: String = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if text.hasPrefix("("), let close = text.firstIndex(of: ")") {
            let code: String = String(text[text.index(after: text.startIndex)..<close])
            let rest: String = String(text[text.index(after: close)...]).trimmingCharacters(in: .whitespaces)
            if !rest.isEmpty { return rest }
            if let number = Int(code) { return id3Name(number) }
            return nil
        }
        if let number = Int(text) { return id3Name(number) }
        return text
    }
}
