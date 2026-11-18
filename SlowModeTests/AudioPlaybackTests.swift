import AVFoundation
import Foundation
import SwiftData
import Testing
@testable import SlowMode

/// Motor falso: registra lo que le pide `PlayerController`.
@MainActor
final class FakeEngine: PlaybackEngine {
    var onFinished: (() -> Void)?
    var onInterruption: ((AudioInterruption) -> Void)?
    var currentTime: Double = 0
    var loadedURLs: [URL] = []
    var applied: [EngineParameters] = []
    var playCount: Int = 0
    var pauseCount: Int = 0
    var seeks: [Double] = []

    func load(url: URL) throws { loadedURLs.append(url) }
    func play() throws { playCount += 1 }
    func pause() { pauseCount += 1 }
    func stop() {}
    func seek(to seconds: Double) { seeks.append(seconds) }
    func apply(_ parameters: EngineParameters) { applied.append(parameters) }
    var loops: [ClosedRange<Double>?] = []
    func setLoop(_ range: ClosedRange<Double>?) { loops.append(range) }
}

struct EngineParametersTests {
    @Test func disabledSlowModeIsNeutral() {
        let settings = SlowSettings(isEnabled: false, tempo: 0.8, pitch: -3, reverb: 40, isLinked: false)
        #expect(settings.engineParameters == .neutral)
    }

    @Test func enabledSlowModeMapsToTimePitchAndReverb() {
        let settings = SlowSettings(isEnabled: true, tempo: 0.85, pitch: -2, reverb: 20, isLinked: false)
        let parameters: EngineParameters = settings.engineParameters
        #expect(abs(parameters.rate - 0.85) < 0.0001)
        #expect(parameters.pitchCents == -200)
        #expect(parameters.reverbMix == 20)
    }

    @Test func linkedPitchUsesVinylCents() {
        let settings = SlowSettings(isEnabled: true, tempo: 0.5, pitch: 0, reverb: 0, isLinked: true)
        #expect(abs(settings.engineParameters.pitchCents - (-1200)) < 0.01)
    }

    @Test func interpolationIsLinear() {
        let middle = EngineParameters.interpolate(.neutral, EngineParameters(rate: 0.5, pitchCents: -400, reverbMix: 40), 0.5)
        #expect(middle == EngineParameters(rate: 0.75, pitchCents: -200, reverbMix: 20))
    }
}

@MainActor
struct PlayerEngineTests {
    private let track = CatalogTrack(id: "local-1", artistId: "x", title: "Real", artist: "Yo", album: "", duration: 100, plays: 0, origin: .localFile)
    private let other = CatalogTrack(id: "local-2", artistId: "x", title: "Otra", artist: "Yo", album: "", duration: 50, plays: 0, origin: .localFile)
    private let url = URL(fileURLWithPath: "/tmp/real.m4a")

    private func makePlayer(_ engine: FakeEngine) -> PlayerController {
        let player = PlayerController(engine: engine)
        let fileURL: URL = url
        player.fileURLProvider = { _ in fileURL }
        return player
    }

    @Test func playingImportedTrackUsesEngine() {
        let engine = FakeEngine()
        let player = makePlayer(engine)
        player.play(track, in: [track], from: "Tu música")
        #expect(engine.loadedURLs == [url])
        #expect(engine.playCount == 1)
        #expect(player.isPlayingRealAudio)
        player.pause()
        #expect(engine.pauseCount == 1)
    }

    @Test func slowModeChangesReachTheEngine() {
        let engine = FakeEngine()
        let player = makePlayer(engine)
        player.play(track, in: [track], from: "Tu música")
        player.slow.isEnabled = true
        player.slow.setTempo(0.85)
        player.slow.setPitch(-2)
        #expect(engine.applied.last == EngineParameters(rate: Float(0.85), pitchCents: -200, reverbMix: 0))
        player.setSlowMode(enabled: false)
        #expect(engine.applied.last == .neutral)
        player.pause()
    }

    @Test func positionComesFromEngineAndSeekIsForwarded() {
        let engine = FakeEngine()
        let player = makePlayer(engine)
        player.play(track, in: [track], from: "Tu música")
        engine.currentTime = 42
        player.tick(seconds: 0.25)
        #expect(player.position == 42)
        player.seek(to: 10)
        #expect(engine.seeks.last == 10)
        player.pause()
    }

    @Test func engineFinishAdvancesQueue() {
        let engine = FakeEngine()
        let player = makePlayer(engine)
        player.play(track, in: [track, other], from: "Tu música")
        engine.onFinished?()
        #expect(player.currentTrack?.id == "local-2")
        #expect(engine.loadedURLs.count == 2)
        #expect(engine.playCount == 2)
        player.pause()
    }

    @Test func interruptionPausesAndResumes() {
        let engine = FakeEngine()
        let player = makePlayer(engine)
        player.play(track, in: [track], from: "Tu música")
        engine.onInterruption?(.began)
        #expect(!player.isPlaying)
        engine.onInterruption?(.ended(shouldResume: true))
        #expect(player.isPlaying)
        engine.onInterruption?(.outputLost)
        #expect(!player.isPlaying)
    }

    @Test func tracksWithoutFileAreSimulated() {
        let engine = FakeEngine()
        let player = PlayerController(engine: engine)
        player.play(track, in: [track], from: "Ejemplo")
        #expect(!player.isPlayingRealAudio)
        #expect(engine.playCount == 0)
        player.tick(seconds: 2)
        #expect(player.position == 2)
        player.pause()
    }
}

@MainActor
struct LocalLibraryImportTests {
    private func makeLibrary() throws -> (LocalLibrary, ModelContainer, URL) {
        let container = try ModelContainer(for: Track.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let directory: URL = FileManager.default.temporaryDirectory.appending(path: "SlowModeTests-\(UUID().uuidString)")
        let library = LocalLibrary(context: container.mainContext, directory: directory)
        return (library, container, directory)
    }

    /// Escribe un WAV de silencio de `seconds` segundos.
    private func makeWAV(named name: String, seconds: Double = 1) throws -> URL {
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
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames))
            buffer.frameLength = frames
            try file.write(from: buffer)
        }
        return url
    }

    @Test func importsWavAndSkipsDuplicates() async throws {
        let (library, container, directory) = try makeLibrary()
        _ = container
        let wav: URL = try makeWAV(named: "Prueba.wav", seconds: 1)

        let first: ImportOutcome = await library.importFiles([wav], origin: .localFile)
        #expect(first.imported == ["Prueba"])
        #expect(library.tracks.count == 1)
        let track: Track = try #require(library.tracks.first)
        #expect(abs(track.duration - 1) < 0.05)
        #expect(track.artist == "Artista desconocido")
        let copied: URL = try #require(library.fileURL(for: track.catalogTrack.id))
        #expect(copied.path.hasPrefix(directory.path))
        #expect(FileManager.default.fileExists(atPath: copied.path))

        let second: ImportOutcome = await library.importFiles([wav], origin: .localFile)
        #expect(second.imported.isEmpty)
        #expect(second.duplicates == ["Prueba"])
        #expect(library.tracks.count == 1)

        library.delete(track)
        #expect(library.tracks.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: copied.path))
    }

    @Test func rejectsFilesThatAreNotAudio() async throws {
        let (library, container, _) = try makeLibrary()
        _ = container
        let fake: URL = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)-falso.mp3")
        try Data("esto no es audio".utf8).write(to: fake)

        let outcome: ImportOutcome = await library.importFiles([fake], origin: .localFile)
        #expect(outcome.imported.isEmpty)
        #expect(outcome.failures.first?.reason == .unsupportedFormat)
        #expect(library.tracks.isEmpty)
    }

    @Test func matchesPresetReferenceToImportedTrack() async throws {
        let (library, container, _) = try makeLibrary()
        _ = container
        let wav: URL = try makeWAV(named: "Glass Hours.wav", seconds: 2)
        _ = await library.importFiles([wav], origin: .originalUpload)

        let reference = PresetTrackReference(title: "glass hours", artist: "Artista desconocido", duration: 3)
        #expect(library.match(reference)?.title == "Glass Hours")
        #expect(library.tracks.first?.origin == .originalUpload)
    }

    @Test func outcomeSummary() {
        var outcome = ImportOutcome()
        outcome.imported = ["a", "b"]
        outcome.duplicates = ["c"]
        outcome.failures = [ImportFailure(fileName: "d", reason: .unsupportedFormat)]
        #expect(outcome.summary == "2 pistas importadas · 1 duplicada omitida · 1 con error")
        #expect(outcome.details.contains("d: Formato no compatible"))
        #expect(outcome.details.contains("Ya estaban en tu biblioteca: c"))
    }
}
