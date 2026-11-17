import Foundation
import Testing
@testable import SlowMode

struct SlowModeMathTests {
    @Test func stretchedDurationMatchesSpecExample() {
        // 3:34 a 0.85× → 4:12
        let stretched: Double = SlowModeMath.stretchedDuration(214, tempo: 0.85)
        #expect(SlowModeFormat.duration(stretched) == "4:12")
    }

    @Test func stretchedDurationAtOriginalTempoIsUnchanged() {
        #expect(SlowModeMath.stretchedDuration(214, tempo: 1) == 214)
    }

    @Test func linkedPitchFollowsVinylRule() {
        #expect(SlowModeMath.linkedPitch(forTempo: 1) == 0)
        #expect(abs(SlowModeMath.linkedPitch(forTempo: 0.5) - (-12)) < 0.0001)
        #expect(abs(SlowModeMath.linkedPitch(forTempo: 0.85) - (-2.8136)) < 0.001)
    }

    @Test func centsConversion() {
        #expect(SlowModeMath.cents(fromSemitones: -2) == -200)
    }

    @Test func clampingRespectsRangesAndSteps() {
        #expect(SlowModeMath.clampTempo(0.3) == 0.5)
        #expect(SlowModeMath.clampTempo(2) == 1.5)
        #expect(abs(SlowModeMath.clampTempo(0.854) - 0.85) < 0.0001)
        #expect(SlowModeMath.clampPitch(-20) == -12)
        #expect(SlowModeMath.clampReverb(22) == 20)
        #expect(SlowModeMath.clampReverb(130) == 100)
    }
}

struct SlowModeFormatTests {
    @Test func tempoAndPitchLabels() {
        #expect(SlowModeFormat.tempo(0.85) == "0.85×")
        #expect(SlowModeFormat.tempo(1) == "1.00×")
        #expect(SlowModeFormat.pitch(-2) == "\u{2212}2 st")
        #expect(SlowModeFormat.pitch(0) == "0 st")
        #expect(SlowModeFormat.pitch(3) == "+3 st")
        #expect(SlowModeFormat.reverb(20) == "20 % reverb")
    }

    @Test func summaryOnlyIncludesChanges() {
        #expect(SlowModeFormat.summary(tempo: 1, pitch: 0, reverb: 0) == nil)
        #expect(SlowModeFormat.summary(tempo: 0.85, pitch: -2, reverb: 0) == "0.85× · \u{2212}2 st")
        #expect(SlowModeFormat.summary(tempo: 0.85, pitch: -2, reverb: 20) == "0.85× · \u{2212}2 st · 20 % reverb")
    }

    @Test func stretchSentence() {
        #expect(SlowModeFormat.stretchSentence(duration: 214, tempo: 0.85) == "15 % más lento · 3:34 pasa a ser 4:12")
        #expect(SlowModeFormat.speedChange(1.15) == "15 % más rápido")
        #expect(SlowModeFormat.speedChange(1) == "Velocidad original")
    }

    @Test func durations() {
        #expect(SlowModeFormat.duration(0) == "0:00")
        #expect(SlowModeFormat.duration(65) == "1:05")
    }

    @Test func counts() {
        #expect(SlowModeFormat.count(1988) == "1.988")
        #expect(SlowModeFormat.count(412) == "412")
        #expect(SlowModeFormat.count(1_234_567) == "1.234.567")
        #expect(SlowModeFormat.compact(940) == "940")
        #expect(SlowModeFormat.compact(12_400) == "12,4 k")
        #expect(SlowModeFormat.compact(3_000) == "3 k")
    }
}
