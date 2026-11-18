import SwiftUI

/// Presets a mano en Reproduciendo, sin abrir el panel: Original, los rápidos y los guardados de esta canción.
/// Tocar uno aplica sus ajustes y activa Slow Mode; "Original" lo desactiva.
/// Mantener pulsado uno guardado: compartir, renombrar o eliminar.
struct SlowPresetBar: View {
    let track: CatalogTrack

    @Environment(PlayerController.self) private var player: PlayerController
    @Environment(PresetStore.self) private var presetStore: PresetStore
    @State private var renaming: SlowPreset?
    @State private var renameText: String = ""

    var body: some View {
        let saved: [SlowPreset] = presetStore.presets(for: track)

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
                    ForEach(saved) { preset in
                        Chip(title: "★ \(preset.name)", isSelected: player.slow == preset.settings) {
                            player.slow = preset.settings
                        }
                        .accessibilityLabel(preset.isMine ? "Tu preset \(preset.name)" : "Preset recibido \(preset.name)")
                        .contextMenu {
                            let file = PresetFile(preset: preset.communityPreset)
                            ShareLink(
                                item: PresetShareItem(file: file),
                                subject: Text(file.name),
                                message: Text(file.shareMessage),
                                preview: SharePreview(file.name)
                            ) {
                                Label("Compartir ajustes", systemImage: "square.and.arrow.up")
                            }
                            Button {
                                renameText = preset.name
                                renaming = preset
                            } label: {
                                Label("Renombrar", systemImage: "pencil")
                            }
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
        .alert(
            "Renombrar preset",
            isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }),
            presenting: renaming
        ) { preset in
            TextField("Nombre", text: $renameText)
            Button("Guardar") { _ = presetStore.rename(preset, to: renameText) }
            Button("Cancelar", role: .cancel) {}
        }
    }
}
