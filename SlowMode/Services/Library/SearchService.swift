import Foundation

enum SearchScope: String, CaseIterable, Identifiable, Sendable {
    case artists, songs, mixes, presets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .artists: return "Artistas"
        case .songs: return "Canciones"
        case .mixes: return "Mezclas"
        case .presets: return "Presets"
        }
    }
}

enum SearchResult: Identifiable, Hashable, Sendable {
    case artist(CatalogArtist)
    case track(CatalogTrack)
    case mix(CatalogMix)
    case preset(CommunityPreset)

    var id: String {
        switch self {
        case .artist(let artist): return "artist-" + artist.id
        case .track(let track): return "track-" + track.id
        case .mix(let mix): return "mix-" + mix.id
        case .preset(let preset): return "preset-" + preset.id
        }
    }
}

/// Búsqueda local sobre el catálogo. Sin distinguir mayúsculas ni tildes.
enum SearchService {
    static func search(_ query: String, scope: SearchScope?, in catalog: SampleCatalog) -> [SearchResult] {
        let q: String = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        func wants(_ s: SearchScope) -> Bool { scope == nil || scope == s }
        func has(_ text: String) -> Bool {
            text.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
        let folded: String = q.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let wantsSlowed: Bool = folded.contains("ralent") || folded.contains("slow")

        var results: [SearchResult] = []
        if wants(.artists) {
            let artists = catalog.artists.filter { has($0.name) || has($0.genre) }.prefix(4)
            results += artists.map { SearchResult.artist($0) }
        }
        if wants(.songs) {
            let tracks = catalog.tracks.filter { has($0.title) || has($0.artist) }.prefix(5)
            results += tracks.map { SearchResult.track($0) }
        }
        if wants(.mixes) {
            let mixes = catalog.mixes.filter { mix in has(mix.title) || has(mix.creator) || mix.tags.contains(where: has) }
            results += mixes.map { SearchResult.mix($0) }
        }
        if wants(.presets) {
            let presets = catalog.presets.filter { preset in
                has(preset.name) || has(preset.creator.handle) || has(preset.track.title) || (wantsSlowed && preset.tempo < 1)
            }
            .sorted { $0.uses > $1.uses }
            .prefix(4)
            results += presets.map { SearchResult.preset($0) }
        }
        return results
    }
}
