import Foundation

/// Cálculos puros de Slow Mode (tempo, tono, duración). Sin estado ni audio.
enum SlowModeMath {
    static let tempoRange: ClosedRange<Double> = 0.5...1.5
    static let tempoStep: Double = 0.01
    static let pitchRange: ClosedRange<Int> = -12...12
    static let reverbRange: ClosedRange<Int> = 0...100
    static let reverbStep: Int = 5

    /// Ajusta al rango y al paso de 0.01.
    static func clampTempo(_ tempo: Double) -> Double {
        let clamped: Double = min(max(tempo, tempoRange.lowerBound), tempoRange.upperBound)
        // Redondea a centésimas dividiendo por 100 (exacto para 0.5, 1.5, etc.).
        return (clamped * 100).rounded() / 100
    }

    static func clampPitch(_ semitones: Int) -> Int {
        min(max(semitones, pitchRange.lowerBound), pitchRange.upperBound)
    }

    /// Ajusta al rango y al paso de 5.
    static func clampReverb(_ percent: Int) -> Int {
        let clamped: Int = min(max(percent, reverbRange.lowerBound), reverbRange.upperBound)
        return Int((Double(clamped) / Double(reverbStep)).rounded()) * reverbStep
    }

    /// Duración real al reproducir a `tempo` (3:34 a 0.85× → 4:12).
    static func stretchedDuration(_ seconds: Double, tempo: Double) -> Double {
        guard tempo > 0 else { return seconds }
        return seconds / tempo
    }

    /// Tono equivalente de un vinilo a esa velocidad: 12·log2(tempo) semitonos.
    static func linkedPitch(forTempo tempo: Double) -> Double {
        guard tempo > 0 else { return 0 }
        return 12 * log2(tempo)
    }

    /// Semitonos → cents para `AVAudioUnitTimePitch.pitch`.
    static func cents(fromSemitones semitones: Double) -> Float {
        Float(semitones * 100)
    }
}
