import Foundation

enum SampleCatalogError: Error, Equatable {
    case missingResource(String)
}

/// Datos de ejemplo locales (JSON en el bundle) con la forma del backend final.
/// Se sustituirán por la biblioteca real (Fase 3) y el backend (Fase 5).
struct SampleCatalog: Sendable {
    let artists: [CatalogArtist]
    let tracks: [CatalogTrack]
    let presets: [CommunityPreset]
    let mixes: [CatalogMix]
    let listeners: [CatalogListener]
    let home: HomeStats

    static func load(from bundle: Bundle = .appResources) throws -> SampleCatalog {
        SampleCatalog(
            artists: try decode([CatalogArtist].self, "sample-artists", bundle),
            tracks: try decode([CatalogTrack].self, "sample-tracks", bundle),
            presets: try decode([CommunityPreset].self, "sample-presets", bundle),
            mixes: try decode([CatalogMix].self, "sample-mixes", bundle),
            listeners: try decode([CatalogListener].self, "sample-listeners", bundle),
            home: try decode(HomeStats.self, "sample-home", bundle)
        )
    }

    func artist(id: String) -> CatalogArtist? {
        artists.first { $0.id == id }
    }

    func tracks(byArtist artistId: String) -> [CatalogTrack] {
        tracks.filter { $0.artistId == artistId }.sorted { $0.plays > $1.plays }
    }

    func presets(byArtist artistId: String) -> [CommunityPreset] {
        presets.filter { $0.artistId == artistId }
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ name: String, _ bundle: Bundle) throws -> T {
        guard let url: URL = bundle.url(forResource: name, withExtension: "json") else {
            throw SampleCatalogError.missingResource(name)
        }
        let data: Data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}

private final class AppBundleToken {}

extension Bundle {
    /// Bundle de la app (también desde los tests, que se alojan en ella).
    static var appResources: Bundle { Bundle(for: AppBundleToken.self) }
}
