import Foundation
import Testing
@testable import SlowMode

struct PresetQueryTests {
    @Test func filtersByType() throws {
        let presets: [CommunityPreset] = try SampleCatalog.load().presets
        let slowed = PresetQuery.apply(presets, filter: .slowed, sort: .popular, likedIds: [])
        let sped = PresetQuery.apply(presets, filter: .spedUp, sort: .popular, likedIds: [])
        let pitchOnly = PresetQuery.apply(presets, filter: .pitchOnly, sort: .popular, likedIds: [])
        #expect(!slowed.isEmpty && slowed.allSatisfy { $0.tempo < 1 })
        #expect(!sped.isEmpty && sped.allSatisfy { $0.tempo > 1 })
        #expect(!pitchOnly.isEmpty && pitchOnly.allSatisfy { $0.tempo == 1 })
        #expect(slowed.count + sped.count + pitchOnly.count == presets.count)
    }

    @Test func likedFilterAndSorting() throws {
        let presets: [CommunityPreset] = try SampleCatalog.load().presets
        let liked = PresetQuery.apply(presets, filter: .liked, sort: .popular, likedIds: ["a0-0-v0"])
        #expect(liked.map(\.id) == ["a0-0-v0"])

        let popular = PresetQuery.apply(presets, filter: .all, sort: .popular, likedIds: [])
        #expect(zip(popular, popular.dropFirst()).allSatisfy { $0.uses >= $1.uses })

        let recent = PresetQuery.apply(presets, filter: .all, sort: .recent, likedIds: [])
        #expect(zip(recent, recent.dropFirst()).allSatisfy { $0.createdAt >= $1.createdAt })

        #expect(PresetQuery.top(presets, count: 6).count == 6)
    }
}

struct SearchServiceTests {
    @Test func emptyQueryReturnsNothing() throws {
        let catalog: SampleCatalog = try SampleCatalog.load()
        #expect(SearchService.search("   ", scope: nil, in: catalog).isEmpty)
    }

    @Test func findsArtistsIgnoringCaseAndAccents() throws {
        let catalog: SampleCatalog = try SampleCatalog.load()
        let results = SearchService.search("luna", scope: .artists, in: catalog)
        #expect(results.first == .artist(try #require(catalog.artist(id: "a0"))))

        let electronic = SearchService.search("electronica", scope: .artists, in: catalog)
        #expect(electronic.count == 3)
    }

    @Test func moodSearchFindsMixes() throws {
        let catalog: SampleCatalog = try SampleCatalog.load()
        let results = SearchService.search("Dia de lluvia", scope: nil, in: catalog)
        #expect(results.contains { if case .mix(let mix) = $0 { return mix.id == "m3" } else { return false } })
    }

    @Test func slowedSearchFindsSlowedPresets() throws {
        let catalog: SampleCatalog = try SampleCatalog.load()
        let results = SearchService.search("Ralentizado", scope: .presets, in: catalog)
        #expect(!results.isEmpty)
        for result in results {
            if case .preset(let preset) = result { #expect(preset.tempo < 1) } else { Issue.record("Tipo inesperado") }
        }
    }

    @Test func scopeLimitsResultTypes() throws {
        let catalog: SampleCatalog = try SampleCatalog.load()
        let results = SearchService.search("Glass", scope: .songs, in: catalog)
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { if case .track = $0 { return true } else { return false } })
    }
}

struct CatalogQueryTests {
    @Test func localTrackMatchesByIdOrMetadata() throws {
        let catalog: SampleCatalog = try SampleCatalog.load()
        let preset: CommunityPreset = try #require(catalog.presets.first)
        #expect(catalog.localTrack(for: preset)?.id == preset.trackId)

        let byMetadata = CommunityPreset(
            id: "x", name: "X", tempo: 0.9, pitch: 0, reverb: 0, linked: false,
            track: PresetTrackReference(title: "glass hours", artist: "LUNA VALE", duration: 216),
            trackId: nil, artistId: nil,
            creator: PresetCreator(handle: "h", color: "#000000", onColor: "#FFFFFF"),
            uses: 0, likes: 0, createdAt: .now
        )
        #expect(catalog.localTrack(for: byMetadata)?.id == "a0-0")

        let missing = CommunityPreset(
            id: "y", name: "Y", tempo: 0.9, pitch: 0, reverb: 0, linked: false,
            track: PresetTrackReference(title: "No existe", artist: "Nadie", duration: 200),
            trackId: nil, artistId: nil,
            creator: PresetCreator(handle: "h", color: "#000000", onColor: "#FFFFFF"),
            uses: 0, likes: 0, createdAt: .now
        )
        #expect(catalog.localTrack(for: missing) == nil)
    }

    @Test func albumsAndGenresAreDerived() throws {
        let catalog: SampleCatalog = try SampleCatalog.load()
        #expect(catalog.albums.count == 11)
        #expect(catalog.albums.first?.trackCount == 4)
        #expect(catalog.genres == ["Dream Pop", "Indie", "Electrónica", "R&B"])
    }

    @Test func artistDirectorySortsAndFilters() throws {
        let catalog: SampleCatalog = try SampleCatalog.load()
        let byName = ArtistDirectory.artists(catalog.artists, genre: nil, sort: .name)
        #expect(byName.first?.name == "Halcyon Drive")
        let indie = ArtistDirectory.artists(catalog.artists, genre: "Indie", sort: .plays)
        #expect(indie.map(\.name) == ["Kaito Rivers", "Paper Harbor", "Otis Wren"])
    }
}

@MainActor
struct LibraryStoreTests {
    @Test func presetLikesAndFollowsPersist() throws {
        let suite: String = "LibraryStoreTests-\(UUID().uuidString)"
        let defaults: UserDefaults = try #require(UserDefaults(suiteName: suite))
        let store = LibraryStore(defaults: defaults)
        store.toggleLike(presetId: "p1")
        store.toggleFollow("u1")
        #expect(store.isLiked(presetId: "p1"))

        let reopened = LibraryStore(defaults: defaults)
        #expect(reopened.isLiked(presetId: "p1"))
        #expect(reopened.isFollowing("u1"))
        reopened.toggleLike(presetId: "p1")
        #expect(!LibraryStore(defaults: defaults).isLiked(presetId: "p1"))
        defaults.removePersistentDomain(forName: suite)
    }
}
