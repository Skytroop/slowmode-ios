import Foundation

/// Ajustes de Slow Mode. Valor puro: el motor de audio (Fase 2) solo lee los `effective…`.
struct SlowSettings: Equatable, Sendable {
    var isEnabled: Bool = false
    var tempo: Double = 1
    var pitch: Int = 0
    var reverb: Int = 0
    /// Vincular tono al tempo (como un vinilo): el tono sigue a la velocidad.
    var isLinked: Bool = false

    /// Velocidad que se aplica. Desactivado ⇒ 1.
    var effectiveTempo: Double { isEnabled ? tempo : 1 }

    /// Tono que se aplica, en semitonos (puede ser fraccionario si está vinculado). Desactivado ⇒ 0.
    var effectivePitch: Double {
        guard isEnabled else { return 0 }
        return isLinked ? SlowModeMath.linkedPitch(forTempo: tempo) : Double(pitch)
    }

    /// Reverb que se aplica. Desactivado ⇒ 0.
    var effectiveReverb: Int { isEnabled ? reverb : 0 }

    /// Tono que se muestra en el panel (redondeado si está vinculado).
    var displayedPitch: Int {
        isLinked ? Int(SlowModeMath.linkedPitch(forTempo: tempo).rounded()) : pitch
    }

    /// Resumen de lo que cambia ("0.85× · −2 st · 20 % reverb"). `nil` si está desactivado o no cambia nada.
    var summary: String? {
        guard isEnabled else { return nil }
        return SlowModeFormat.summary(tempo: tempo, pitch: displayedPitch, reverb: reverb)
    }

    mutating func setTempo(_ value: Double) {
        tempo = SlowModeMath.clampTempo(value)
    }

    mutating func setPitch(_ value: Int) {
        pitch = SlowModeMath.clampPitch(value)
    }

    mutating func setReverb(_ value: Int) {
        reverb = SlowModeMath.clampReverb(value)
    }

    mutating func apply(_ preset: QuickPreset) {
        tempo = preset.tempo
        pitch = preset.pitch
        reverb = preset.reverb
        isLinked = false
    }

    func matches(_ preset: QuickPreset) -> Bool {
        !isLinked && abs(tempo - preset.tempo) < 0.001 && pitch == preset.pitch && reverb == preset.reverb
    }
}

/// Presets rápidos del panel de Slow Mode.
struct QuickPreset: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let tempo: Double
    let pitch: Int
    let reverb: Int

    static let all: [QuickPreset] = [
        QuickPreset(id: "original", name: "Original", tempo: 1, pitch: 0, reverb: 0),
        QuickPreset(id: "slowed", name: "Ralentizado", tempo: 0.85, pitch: -2, reverb: 20),
        QuickPreset(id: "deep", name: "Profundo", tempo: 0.75, pitch: -4, reverb: 45),
        QuickPreset(id: "spedUp", name: "Acelerado", tempo: 1.15, pitch: 2, reverb: 0),
    ]
}
