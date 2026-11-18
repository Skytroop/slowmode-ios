import SwiftUI

/// Presets a mano en Reproduciendo, sin abrir el panel: Original, los rápidos y los tuyos de esta canción.
/// Tocar uno aplica sus ajustes y activa Slow Mode; "Original" lo desactiva.
struct SlowPresetBar: View {
    let track: CatalogTrack

    @Environment(PlayerController.self) private var player: PlayerController
    @Environment(PresetStore.self) private var presetStore: PresetStore

    var body: some View {
        let mine: [SlowPreset] = presetStore.presets(for: track)

        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Chip(title: "Original", isSelected: !player.slow.isEnabled) {
                        player.setSlowMode(enabled: false)
                    }
                    ForEach(QuickPreset.all.dropFirst()) { quick in
                        Chip(title: quick.name, isSelected: player.slow.isEnabled && player.slow.matches(quick)) {
                            var settings: SlowSettings = player.slow
                            settings.apply(quick)
                            settings.isEnabled = true
                            player.slow = settings
                        }
                        .accessibilityHint("\(SlowModeFormat.tempo(quick.tempo)), \(SlowModeFormat.pitch(quick.pitch))")
                    }
                    ForEach(mine) { preset in
                        Chip(title: "★ \(preset.name)", isSelected: player.slow == preset.settings) {
                            player.slow = preset.settings
                        }
                        .accessibilityLabel("Tu preset \(preset.name)")
                        .contextMenu {
                            Button(role: .destructive) {
                                presetStore.delete(preset)
                            } label: {
                                Label("Eliminar preset", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Presets de Slow Mode")
    }
}
