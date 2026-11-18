import Foundation
import SwiftData
import Testing
@testable import SlowMode

@MainActor
struct LoopTests {
    private let track = CatalogTrack(id: "t", artistId: "a", title: "Canción", artist: "A", album: "", duration: 200, plays: 0, origin: .localFile)
    private let next = CatalogTrack(id: "n", artistId: "a", title: "Otra", artist: "A", album: "", duration: 100, plays: 0, origin: .localFile)

    @Test func simulatedPlaybackWrapsInsideLoop() {
        let player = PlayerController()
        player.play(track, in: [track, next], from: "A")
        #expect(player.setLoop(start: 90, end: 100))
        #expect(player.position == 90)
        player.tick(seconds: 9)
        #expect(player.position == 99)
        player.tick(seconds: 2)
        #expect(player.position == 90)
        #expect(player.currentTrack?.id == "t")
        player.pause()
    }

    @Test func tooShortLoopIsRejected() {
        let player = PlayerController()
        player.play(track, in: [track], from: "A")
        #expect(!player.setLoop(start: 90, end: 90.5))
        #expect(player.loopRange == nil)
        player.pause()
    }

    @Test func seekStaysInsideLoopAndLoopClearsOnTrackChange() {
        let player = PlayerController()
        player.play(track, in: [track, next], from: "A")
        player.setLoop(start: 90, end: 100)
        player.seek(to: 150)
        #expect(player.position == 100)
        player.seek(to: 10)
        #expect(player.position == 90)
        player.next()
        #expect(player.loopRange == nil)
        player.pause()
    }

    @Test func loopIsForwardedToEngine() {
        let engine = FakeEngine()
        let player = PlayerController(engine: engine)
        player.fileURLProvider = { _ in URL(fileURLWithPath: "/tmp/x.mp3") }
        player.play(track, in: [track], from: "A")
        player.setLoop(start: 90, end: 100)
        #expect(engine.loops.last == .some(90...100))
        player.clearLoop()
        #expect(engine.loops.last == .some(nil))
        player.pause()
    }
}

@MainActor
struct PresetStoreTests {
    private let track = CatalogTrack(id: "local-1", artistId: "a", title: "Glass Hours", artist: "Luna Vale", album: "", duration: 214, plays: 0, origin: .localFile)

    private func makeStore() throws -> (PresetStore, ModelContainer) {
        let container = try ModelContainer(for: Track.self, SlowPreset.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return (PresetStore(context: container.mainContext), container)
    }

    @Test func savesAndFindsPresetForTrack() throws {
        let (store, container) = try makeStore()
        _ = container
        let settings = SlowSettings(isEnabled: true, tempo: 0.8, pitch: -3, reverb: 30, isLinked: false)
        let saved: SlowPreset = try #require(store.save(name: "  Mi slowed ", settings: settings, for: track))
        #expect(saved.name == "Mi slowed")
        #expect(store.presets.count == 1)

        let sameSongOtherCopy = CatalogTrack(id: "local-2", artistId: "a", title: "glass hours", artist: "LUNA VALE", album: "", duration: 216, plays: 0, origin: .localFile)
        #expect(store.presets(for: sameSongOtherCopy).count == 1)
        #expect(store.presets(for: sameSongOtherCopy).first?.settings == settings)

        let community: CommunityPreset = try #require(store.communityPresets.first)
        #expect(community.id.hasPrefix(MinePresetID.prefix))
        #expect(community.track.title == "Glass Hours")
        store.delete(presetId: community.id)
        #expect(store.presets.isEmpty)
    }

    @Test func emptyNameIsRejected() throws {
        let (store, container) = try makeStore()
        _ = container
        #expect(store.save(name: "   ", settings: SlowSettings(isEnabled: true, tempo: 0.9), for: track) == nil)
    }

    @Test func linkedPresetStoresDisplayedPitch() throws {
        let (store, container) = try makeStore()
        _ = container
        let settings = SlowSettings(isEnabled: true, tempo: 0.75, pitch: 0, reverb: 0, isLinked: true)
        let saved: SlowPreset = try #require(store.save(name: "Vinilo", settings: settings, for: track))
        #expect(saved.pitch == -5)
        #expect(saved.linked)
    }

    @Test func suggestedNames() {
        #expect(PresetStore.suggestedName(for: SlowSettings(isEnabled: true, tempo: 0.85, pitch: -2, reverb: 20)) == "Ralentizado 0.85×")
        #expect(PresetStore.suggestedName(for: SlowSettings(isEnabled: true, tempo: 0.8, pitch: 0, reverb: 0)) == "Ralentizado 0.80×")
        #expect(PresetStore.suggestedName(for: SlowSettings(isEnabled: true, tempo: 1.2, pitch: 0, reverb: 0)) == "Acelerado 1.20×")
    }

    @Test func badgeDescribesTheMode() {
        #expect(SlowModeFormat.badge(for: SlowSettings(isEnabled: true, tempo: 0.85, pitch: -2, reverb: 0)) == "Ralentizado · 0.85× · \u{2212}2 st")
        #expect(SlowModeFormat.badge(for: SlowSettings(isEnabled: false, tempo: 0.85)) == nil)
    }
}
