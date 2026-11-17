import Foundation
import Testing
@testable import SlowMode

struct SlowSettingsTests {
    @Test func disabledSettingsAreNeutral() {
        let settings = SlowSettings(isEnabled: false, tempo: 0.8, pitch: -3, reverb: 40, isLinked: false)
        #expect(settings.effectiveTempo == 1)
        #expect(settings.effectivePitch == 0)
        #expect(settings.effectiveReverb == 0)
        #expect(settings.summary == nil)
    }

    @Test func enabledSettingsApply() {
        let settings = SlowSettings(isEnabled: true, tempo: 0.85, pitch: -2, reverb: 20, isLinked: false)
        #expect(settings.effectiveTempo == 0.85)
        #expect(settings.effectivePitch == -2)
        #expect(settings.effectiveReverb == 20)
        #expect(settings.summary == "0.85× · \u{2212}2 st · 20 % reverb")
    }

    @Test func linkedPitchFollowsTempo() {
        let settings = SlowSettings(isEnabled: true, tempo: 0.75, pitch: 5, reverb: 0, isLinked: true)
        #expect(abs(settings.effectivePitch - (-4.98)) < 0.01)
        #expect(settings.displayedPitch == -5)
    }

    @Test func settersClamp() {
        var settings = SlowSettings()
        settings.setTempo(3)
        settings.setPitch(-40)
        settings.setReverb(103)
        #expect(settings.tempo == 1.5)
        #expect(settings.pitch == -12)
        #expect(settings.reverb == 100)
    }

    @Test func quickPresetsApplyAndMatch() {
        var settings = SlowSettings(isEnabled: true, tempo: 1, pitch: 0, reverb: 0, isLinked: true)
        let slowed: QuickPreset = QuickPreset.all[1]
        settings.apply(slowed)
        #expect(settings.tempo == 0.85)
        #expect(settings.pitch == -2)
        #expect(settings.reverb == 20)
        #expect(settings.isLinked == false)
        #expect(settings.matches(slowed))
        #expect(!settings.matches(QuickPreset.all[0]))
    }
}

@MainActor
struct PlayerControllerTests {
    private func makeTracks() -> [CatalogTrack] {
        [
            CatalogTrack(id: "t1", artistId: "a", title: "Uno", artist: "A", album: "X", duration: 10, plays: 3, origin: .localFile),
            CatalogTrack(id: "t2", artistId: "a", title: "Dos", artist: "A", album: "X", duration: 20, plays: 2, origin: .localFile),
        ]
    }

    @Test func tickAdvancesByEffectiveTempo() {
        let player = PlayerController()
        let tracks = makeTracks()
        player.play(tracks[1], in: tracks, from: "A")
        player.slow = SlowSettings(isEnabled: true, tempo: 0.5, pitch: 0, reverb: 0, isLinked: false)
        player.tick(seconds: 4)
        #expect(player.position == 2)
        #expect(player.displayedDuration == 40)
        player.togglePlayPause()
    }

    @Test func endOfQueueStopsWhenRepeatIsOff() {
        let player = PlayerController()
        let tracks = makeTracks()
        player.play(tracks[1], in: tracks, from: "A")
        player.tick(seconds: 25)
        #expect(player.isPlaying == false)
        #expect(player.currentTrack?.id == "t2")
    }

    @Test func endOfTrackAdvancesToNext() {
        let player = PlayerController()
        let tracks = makeTracks()
        player.play(tracks[0], in: tracks, from: "A")
        player.tick(seconds: 11)
        #expect(player.currentTrack?.id == "t2")
        #expect(player.position == 0)
        player.togglePlayPause()
    }

    @Test func repeatOneRestartsTrack() {
        let player = PlayerController()
        let tracks = makeTracks()
        player.play(tracks[0], in: tracks, from: "A")
        player.repeatMode = .one
        player.tick(seconds: 11)
        #expect(player.currentTrack?.id == "t1")
        #expect(player.position == 0)
        player.togglePlayPause()
    }

    @Test func nextWrapsAndPreviousRestartsAfterThreeSeconds() {
        let player = PlayerController()
        let tracks = makeTracks()
        player.play(tracks[1], in: tracks, from: "A")
        player.next()
        #expect(player.currentTrack?.id == "t1")
        player.seek(to: 5)
        player.previous()
        #expect(player.currentTrack?.id == "t1")
        #expect(player.position == 0)
        player.previous()
        #expect(player.currentTrack?.id == "t2")
        player.togglePlayPause()
    }

    @Test func applyingPresetEnablesSlowModeAndDisablingClearsIt() throws {
        let catalog: SampleCatalog = try SampleCatalog.load()
        let preset: CommunityPreset = try #require(catalog.presets.first)
        let track: CatalogTrack = try #require(catalog.localTrack(for: preset))
        let player = PlayerController()
        player.apply(preset, to: track)
        #expect(player.slow.isEnabled)
        #expect(player.slow.tempo == preset.tempo)
        #expect(player.activePreset?.id == preset.id)
        player.setSlowMode(enabled: false)
        #expect(player.activePreset == nil)
        player.togglePlayPause()
    }

    @Test func repeatModeCycles() {
        #expect(RepeatMode.off.next == .all)
        #expect(RepeatMode.all.next == .one)
        #expect(RepeatMode.one.next == .off)
    }
}
