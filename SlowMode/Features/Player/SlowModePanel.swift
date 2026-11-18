import SwiftUI

/// Panel de Slow Mode en Reproduciendo: plegado por defecto; activarlo lo despliega.
struct SlowModePanel: View {
    @Binding var isExpanded: Bool
    let trackDuration: Double
    let presetCount: Int
    let onShowPresets: () -> Void

    @Environment(PlayerController.self) private var player: PlayerController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool
    @State private var showsShareInfo: Bool = false

    private var summaryText: String {
        guard player.slow.isEnabled else { return "Desactivado" }
        return player.slow.summary ?? "Sin cambios"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if isExpanded {
                controls
                    .transition(.opacity)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: Radius.card))
        .alert("Compartir preset", isPresented: $showsShareInfo) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text("Se compartirán solo los ajustes (\(summaryText)) y el título y artista de la pista, nunca el audio. Llega en la Fase 4.")
        }
    }

    private func animate(_ change: () -> Void) {
        if reduceMotion {
            change()
        } else {
            withAnimation(.spring(duration: 0.4)) { change() }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "dial.low.fill")
                .font(.title3)
                .foregroundStyle(player.slow.isEnabled ? Palette.periwinkle : Palette.textSecondary)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Slow Mode")
                    .font(.headline)
                Text(summaryText)
                    .textStyle(.caption)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Toggle(
                "Slow Mode",
                isOn: Binding(
                    get: { player.slow.isEnabled },
                    set: { enabled in
                        player.setSlowMode(enabled: enabled)
                        if enabled { animate { isExpanded = true } }
                    }
                )
            )
            .labelsHidden()
            .tint(Palette.periwinkle)
            .accessibilityLabel("Slow Mode")

            Button {
                animate { isExpanded.toggle() }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.body.weight(.semibold))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Plegar Slow Mode" : "Desplegar Slow Mode")
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
                SlowSliderRow(
                    title: "Tempo",
                    valueText: SlowModeFormat.tempo(player.slow.tempo),
                    value: Binding(get: { player.slow.tempo }, set: { player.slow.setTempo($0) }),
                    range: SlowModeMath.tempoRange,
                    step: SlowModeMath.tempoStep,
                    showsCenterMark: true,
                    decrementLabel: "Reducir tempo",
                    incrementLabel: "Aumentar tempo",
                    onDecrement: { player.slow.setTempo(player.slow.tempo - 0.01) },
                    onIncrement: { player.slow.setTempo(player.slow.tempo + 0.01) }
                )
                SlowSliderRow(
                    title: "Tono",
                    valueText: SlowModeFormat.pitch(player.slow.displayedPitch),
                    value: Binding(
                        get: { Double(player.slow.displayedPitch) },
                        set: { player.slow.setPitch(Int($0.rounded())) }
                    ),
                    range: -12...12,
                    step: 1,
                    isDisabled: player.slow.isLinked,
                    decrementLabel: "Bajar tono",
                    incrementLabel: "Subir tono",
                    onDecrement: { player.slow.setPitch(player.slow.pitch - 1) },
                    onIncrement: { player.slow.setPitch(player.slow.pitch + 1) }
                )
                SlowSliderRow(
                    title: "Reverb",
                    valueText: "\(player.slow.reverb) %",
                    value: Binding(
                        get: { Double(player.slow.reverb) },
                        set: { player.slow.setReverb(Int($0.rounded())) }
                    ),
                    range: 0...100,
                    step: 5,
                    decrementLabel: "Menos reverb",
                    incrementLabel: "Más reverb",
                    onDecrement: { player.slow.setReverb(player.slow.reverb - 5) },
                    onIncrement: { player.slow.setReverb(player.slow.reverb + 5) }
                )
                Toggle(
                    "Vincular tono al tempo",
                    isOn: Binding(get: { player.slow.isLinked }, set: { player.slow.isLinked = $0 })
                )
                .tint(Palette.periwinkle)
                .frame(minHeight: 44)

                ScrollView(.horizontal, showsIndicators: false) {
                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 8) {
                            ForEach(QuickPreset.all) { preset in
                                Chip(title: preset.name, isSelected: player.slow.matches(preset)) {
                                    player.slow.apply(preset)
                                }
                            }
                        }
                    }
                }

                Text(SlowModeFormat.stretchSentence(duration: trackDuration, tempo: player.slow.tempo))
                    .textStyle(.caption)
                    .monospacedDigit()
            }
            .disabled(!player.slow.isEnabled)
            .opacity(player.slow.isEnabled ? 1 : 0.5)

            HStack(spacing: 12) {
                Button {
                    showsShareInfo = true
                } label: {
                    Label("Compartir preset", systemImage: "square.and.arrow.up")
                        .frame(minHeight: 36)
                }
                .buttonStyle(.glass)
                .disabled(!player.slow.isEnabled)

                Spacer(minLength: 0)

                Button(action: onShowPresets) {
                    Text(presetCount == 1 ? "1 preset" : "\(presetCount) presets")
                        .monospacedDigit()
                        .frame(minHeight: 36)
                }
                .buttonStyle(.glass)
            }
        }
    }
}

/// Fila de control: título, valor, botones −/+ y slider.
struct SlowSliderRow: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var showsCenterMark: Bool = false
    var isDisabled: Bool = false
    let decrementLabel: String
    let incrementLabel: String
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(valueText)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(Palette.textSecondary)
            }
            .accessibilityHidden(true)

            HStack(spacing: 4) {
                stepButton(symbol: "minus", label: decrementLabel, action: onDecrement)
                Slider(value: $value, in: range, step: step) {
                    Text(title)
                }
                .accessibilityValue(valueText)
                .overlay {
                    if showsCenterMark {
                        Capsule()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 2, height: 14)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                stepButton(symbol: "plus", label: incrementLabel, action: onIncrement)
            }
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
    }

    private func stepButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.footnote.weight(.bold))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
