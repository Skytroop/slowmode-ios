import AVFoundation
import Foundation
import SwiftData
import Testing
@testable import SlowMode

enum TestData {
    @MainActor
    static func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Track.self, SlowPreset.self, Playlist.self, PlayEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// WAV de silencio en una carpeta propia, con el nombre exacto.
    static func makeWAV(named name: String, seconds: Double = 1) throws -> URL {
        let folder: URL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url: URL = folder.appending(path: name)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        do {
            let file = try AVAudioFile(forWriting: url, settings: settings)
            let frames = AVAudioFrameCount(44_100 * seconds)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames) else {
                throw ImportError.unreadable
            }
            buffer.frameLength = frames
            try file.write(from: buffer)
        }
        return url
    }
}

struct ListeningTrackerTests {
    private func tick(_ session: UUID, _ seconds: Double, duration: Double = 200) -> ListeningTick {
        ListeningTick(sessionID: session, trackID: "local-x", seconds: seconds, tempo: 1, duration: duration)
    }

    @Test func thresholdIsThirtySecondsOrHalf() {
        #expect(ListeningTracker.threshold(forDuration: 200) == 30)
        #expect(ListeningTracker.threshold(forDuration: 40) == 20)
    }

    @Test func countsOnceThenExtends() {
        var tracker = ListeningTracker()
        let session = UUID()
        #expect(tracker.record(tick(session, 29)) == .none)
        #expect(tracker.record(tick(session, 1)) == .counted(seconds: 30))
        #expect(tracker.record(tick(session, 5)) == .extended(seconds: 5))
    }

    @Test func newSessionStartsOver() {
        var tracker = ListeningTracker()
        let first = UUID()
        _ = tracker.record(tick(first, 30))
        let second = UUID()
        #expect(tracker.record(tick(second, 10)) == .none)
        #expect(tracker.record(tick(second, 20)) == .counted(seconds: 30))
    }
}

struct ListeningStatsTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid") ?? .current
        return calendar
    }()

    private func day(_ offset: Int, from now: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: now) ?? now
    }

    @Test func streakCountsConsecutiveDays() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let events: [PlaySnapshot] = [0, -1, -3].map { PlaySnapshot(date: day($0, from: now), seconds: 60, genre: "Indie") }
        #expect(ListeningStats.streak(events, now: now, calendar: calendar) == 2)
        let fromYesterday: [PlaySnapshot] = [-1, -2].map { PlaySnapshot(date: day($0, from: now), seconds: 60, genre: "") }
        #expect(ListeningStats.streak(fromYesterday, now: now, calendar: calendar) == 2)
        let old: [PlaySnapshot] = [PlaySnapshot(date: day(-5, from: now), seconds: 60, genre: "")]
        #expect(ListeningStats.streak(old, now: now, calendar: calendar) == 0)
        #expect(ListeningStats.streak([], now: now, calendar: calendar) == 0)
    }

    @Test func topGenresByListenedTime() {
        let now = Date()
        let events: [PlaySnapshot] = [
            PlaySnapshot(date: now, seconds: 300, genre: "Indie"),
            PlaySnapshot(date: now, seconds: 100, genre: "R&B"),
            PlaySnapshot(date: now, seconds: 100, genre: ""),
        ]
        let genres: [GenreShare] = ListeningStats.topGenres(events)
        #expect(genres.first == GenreShare(genre: "Indie", percent: 60))
        #expect(genres.contains(GenreShare(genre: ListeningStats.noGenre, percent: 20)))
        #expect(ListeningStats.topGenres([]).isEmpty)
    }

    @Test func artistsAreGroupedAndRanked() {
        let tracks: [TrackSnapshot] = [
            TrackSnapshot(artist: "Luna", genre: "Dream Pop", plays: 3),
            TrackSnapshot(artist: "luna", genre: "Dream Pop", plays: 2),
            TrackSnapshot(artist: "Kai", genre: "", plays: 7),
            TrackSnapshot(artist: "Zoe", genre: "Indie", plays: 0),
        ]
        let artists: [CatalogArtist] = ListeningStats.artists(from: tracks)
        #expect(artists.map(\.name) == ["Kai", "Luna", "Zoe"])
        #expect(artists[1].plays == 5)
        #expect(artists[1].genre == "Dream Pop")
        #expect(artists[0].genre == ListeningStats.noGenre)
        #expect(artists[0].rank == 1)
        #expect(artists[0].id == LocalTrackID.artistId(for: "Kai"))

        let map: DiscoverMap = ListeningStats.discover(artists)
        #expect(map.centerArtistId == artists[0].id)
        #expect(map.similar.count == 2)
    }

    @Test func artistColorsAreStable() {
        #expect(ArtistPalette.colors(for: "Luna Vale").background == ArtistPalette.colors(for: "luna vale").background)
    }

    @Test func genreNamesAreNormalized() {
        #expect(GenreName.normalize("(13)") == "Pop")
        #expect(GenreName.normalize("(17)Rock") == "Rock")
        #expect(GenreName.normalize("13") == "Pop")
        #expect(GenreName.normalize(" Indie ") == "Indie")
        #expect(GenreName.normalize("") == nil)
        #expect(GenreName.id3Name(999) == nil)
    }
}

@MainActor
struct LocalLibraryPhase3Tests {
    private func makeLibrary(now: Date = Date()) throws -> (LocalLibrary, ModelContainer) {
        let container = try TestData.makeContainer()
        let directory: URL = FileManager.default.temporaryDirectory.appending(path: "SlowModeTests-\(UUID().uuidString)")
        let library = LocalLibrary(context: container.mainContext, directory: directory, now: { now }, backfillsGenres: false)
        return (library, container)
    }

    @Test func listeningCountsAPlayAndFeedsHomeStats() async throws {
        let (library, container) = try makeLibrary()
        _ = container
        _ = await library.importFiles([try TestData.makeWAV(named: "Uno.wav")], origin: .localFile)
        let track: CatalogTrack = try #require(library.catalogTracks.first)

        let session = UUID()
        for _ in 0..<120 {
            library.handle(ListeningTick(sessionID: session, trackID: track.id, seconds: 0.25, tempo: 0.85, duration: 200))
        }
        #expect(library.homeStats.songsPlayed == 1)
        #expect(library.homeStats.streakDays == 1)
        #expect(library.homeStats.trackCount == 1)
        #expect(library.artists.first?.plays == 1)
        #expect(library.catalogTracks.first?.plays == 1)

        // Seguir escuchando en la misma sesión no cuenta otra vez.
        for _ in 0..<200 {
            library.handle(ListeningTick(sessionID: session, trackID: track.id, seconds: 0.25, tempo: 0.85, duration: 200))
        }
        #expect(library.homeStats.songsPlayed == 1)
    }

    @Test func sampleTracksAreNotCounted() throws {
        let (library, container) = try makeLibrary()
        _ = container
        library.handle(ListeningTick(sessionID: UUID(), trackID: "a0-0", seconds: 60, tempo: 1, duration: 200))
        #expect(library.homeStats.songsPlayed == 0)
    }

    @Test func likesAndPlaylists() async throws {
        let (library, container) = try makeLibrary()
        _ = container
        _ = await library.importFiles([try TestData.makeWAV(named: "A.wav"), try TestData.makeWAV(named: "B.wav", seconds: 2)], origin: .localFile)
        #expect(library.catalogTracks.count == 2)
        let first: CatalogTrack = library.catalogTracks[0]
        let second: CatalogTrack = library.catalogTracks[1]

        library.toggleLike(catalogId: first.id)
        #expect(library.isLiked(catalogId: first.id))
        #expect(library.likedTracks.map(\.id) == [first.id])

        #expect(library.createPlaylist(named: "  ") == nil)
        let playlist: Playlist = try #require(library.createPlaylist(named: "Noche"))
        #expect(library.add(trackCatalogId: second.id, to: playlist))
        #expect(library.add(trackCatalogId: first.id, to: playlist))
        #expect(!library.add(trackCatalogId: first.id, to: playlist))
        #expect(!library.add(trackCatalogId: "a0-0", to: playlist))
        #expect(library.tracks(in: playlist).map(\.id) == [second.id, first.id])

        library.remove(trackCatalogId: second.id, from: playlist)
        #expect(library.tracks(in: playlist).map(\.id) == [first.id])

        let stored: Track = try #require(library.track(catalogId: first.id))
        library.delete(stored)
        #expect(library.tracks(in: playlist).isEmpty)

        library.delete(playlist)
        #expect(library.playlists.isEmpty)
    }

    @Test func genreCanBeSetForAnArtist() async throws {
        let (library, container) = try makeLibrary()
        _ = container
        _ = await library.importFiles([try TestData.makeWAV(named: "Uno.wav")], origin: .localFile)
        let artistId: String = try #require(library.artists.first?.id)
        #expect(library.artists.first?.genre == ListeningStats.noGenre)
        library.setGenre("Lo-Fi", forArtistId: artistId)
        #expect(library.artists.first?.genre == "Lo-Fi")
    }

    @Test func duplicatesCanBeImportedAnyway() async throws {
        let (library, container) = try makeLibrary()
        _ = container
        let wav: URL = try TestData.makeWAV(named: "Repetida.wav")
        _ = await library.importFiles([wav], origin: .localFile)
        let second: ImportOutcome = await library.importFiles([wav], origin: .localFile)
        #expect(second.duplicateURLs == [wav])
        let forced: ImportOutcome = await library.importFiles(second.duplicateURLs, origin: .localFile, allowDuplicates: true)
        #expect(forced.imported == ["Repetida"])
        #expect(library.tracks.count == 2)
    }

    @Test func userCatalogUsesYourMusic() async throws {
        let (library, container) = try makeLibrary()
        _ = container
        _ = await library.importFiles([try TestData.makeWAV(named: "Uno.wav")], origin: .localFile)
        let community: SampleCatalog = try SampleCatalog.load()
        let catalog: SampleCatalog = library.userCatalog(community: community, myPresets: [])
        #expect(catalog.tracks.count == 1)
        #expect(catalog.artists.count == 1)
        let artist: CatalogArtist = try #require(catalog.artists.first)
        #expect(catalog.tracks(byArtist: artist.id).count == 1)
        #expect(catalog.mixes.count == community.mixes.count)
        #expect(SearchService.search("Uno", scope: .songs, in: catalog).count == 1)
    }
}

@MainActor
struct PlayerListeningTests {
    @Test func ticksCarryANewSessionPerTrack() {
        let player = PlayerController()
        var ticks: [ListeningTick] = []
        player.listeningObserver = { ticks.append($0) }
        let a = CatalogTrack(id: "local-a", artistId: "x", title: "A", artist: "X", album: "", duration: 100, plays: 0, origin: .localFile)
        let b = CatalogTrack(id: "local-b", artistId: "x", title: "B", artist: "X", album: "", duration: 100, plays: 0, origin: .localFile)
        player.play(a, in: [a, b], from: "X")
        player.tick(seconds: 0.25)
        player.tick(seconds: 0.25)
        player.next()
        player.tick(seconds: 0.25)
        #expect(ticks.count == 3)
        #expect(ticks[0].sessionID == ticks[1].sessionID)
        #expect(ticks[1].sessionID != ticks[2].sessionID)
        #expect(ticks[2].trackID == "local-b")
        player.pause()
    }
}
