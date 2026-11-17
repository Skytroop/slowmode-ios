import Foundation
import Testing
@testable import SlowMode

struct SampleCatalogTests {
    @Test func loadsAllSampleFiles() throws {
        let catalog: SampleCatalog = try SampleCatalog.load()
        #expect(catalog.artists.count == 10)
        #expect(catalog.tracks.count == 42)
        #expect(catalog.presets.count == 70)
        #expect(catalog.mixes.count == 4)
        #expect(catalog.listeners.count == 4)
        #expect(catalog.home.trackCount == catalog.tracks.count)
    }

    @Test func referencesAreConsistent() throws {
        let catalog: SampleCatalog = try SampleCatalog.load()
        let trackIds: Set<String> = Set(catalog.tracks.map(\.id))
        for preset in catalog.presets {
            if let trackId = preset.trackId {
                #expect(trackIds.contains(trackId), "Preset \(preset.id) apunta a una pista inexistente")
            }
        }
        #expect(catalog.artist(id: catalog.home.discover.centerArtistId) != nil)
        for similar in catalog.home.discover.similar {
            #expect(catalog.artist(id: similar.artistId) != nil)
        }
    }

    @Test func originalsAreMarkedAsUploads() throws {
        let catalog: SampleCatalog = try SampleCatalog.load()
        let originals: [CatalogTrack] = catalog.tracks.filter { $0.origin == .originalUpload }
        #expect(originals.map(\.title) == ["Kitchen Demo 3", "Rooftop Loop"])
    }

    @Test func artistQueries() throws {
        let catalog: SampleCatalog = try SampleCatalog.load()
        let tracks: [CatalogTrack] = catalog.tracks(byArtist: "a0")
        #expect(tracks.count == 4)
        #expect(tracks.first?.title == "Glass Hours")
        #expect(!catalog.presets(byArtist: "a0").isEmpty)
    }

    @Test func initials() {
        #expect(Initials.fromName("Luna Vale") == "LV")
        #expect(Initials.fromHandle("tape.hiss") == "TA")
        #expect(Initials.fromHandle("3amdrive") == "3A")
    }
}
