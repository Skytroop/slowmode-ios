import SwiftUI

/// Fila de preset (Comunidad, Artista, Biblioteca): creador, nombre, usos, pista, pills, me gusta y aplicar.
struct PresetRow: View {
    let preset: CommunityPreset
    let showsArtist: Bool
    let isLiked: Bool
    let isActive: Bool
    let onPlay: () -> Void
    let onLike: () -> Void

    private var subtitle: String {
        var text: String = "@\(preset.creator.handle) · \(preset.track.title)"
        if showsArtist { text += " — \(preset.track.artist)" }
        return text
    }

    private var likeCount: Int { preset.likes + (isLiked ? 1 : 0) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            InitialsAvatar(
                initials: preset.creator.initials,
                background: Color(hex: preset.creator.color),
                foreground: Color(hex: preset.creator.onColor),
                size: 40
            )
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(preset.name)
                        .textStyle(.body)
                        .foregroundStyle(isActive ? Palette.periwinkle : Palette.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(SlowModeFormat.compact(preset.uses)) usos")
                        .textStyle(.caption)
                        .monospacedDigit()
                }
                Text(subtitle)
                    .textStyle(.caption)
                    .lineLimit(1)
                PresetPills(tempo: preset.tempo, pitch: preset.pitch, reverb: preset.reverb)
            }
            .accessibilityElement(children: .combine)

            VStack(spacing: 0) {
                Button(action: onPlay) {
                    Image(systemName: "play.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isActive ? Palette.ink : Palette.textPrimary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(
                    isActive ? Glass.regular.tint(Palette.periwinkle).interactive() : Glass.regular.interactive(),
                    in: .circle
                )
                .accessibilityLabel("Aplicar \(preset.name) a tu copia de \(preset.track.title)")

                Button(action: onLike) {
                    HStack(spacing: 3) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                        Text(SlowModeFormat.compact(likeCount))
                            .monospacedDigit()
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isLiked ? Palette.pink : Palette.textSecondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Me gusta")
                .accessibilityValue("\(likeCount)")
                .accessibilityAddTraits(isLiked ? .isSelected : [])
            }
        }
        .padding(.vertical, 10)
    }
}

/// Lista de presets con filtros (Todos, Ralentizado, Acelerado, Solo tono, Me gusta) y orden.
/// El botón de play aplica el preset a la pista local; si no la tienes, ofrece importarla.
struct PresetListSection: View {
    let presets: [CommunityPreset]
    var showsArtist: Bool = true
    var showsControls: Bool = true
    var emptyTitle: String = "Sin presets"
    var emptyMessage: String = "Todavía no hay presets que coincidan."
    /// Si se indica, los presets propios se pueden eliminar manteniendo pulsado.
    var onDelete: ((CommunityPreset) -> Void)? = nil

    @Environment(CatalogStore.self) private var store: CatalogStore
    @Environment(LibraryStore.self) private var library: LibraryStore
    @Environment(LocalLibrary.self) private var localLibrary: LocalLibrary
    @Environment(PlayerController.self) private var player: PlayerController
    @Environment(AppNavigation.self) private var navigation: AppNavigation
    @State private var filter: PresetFilter = .all
    @State private var sort: PresetSort = .popular
    @State private var missingPreset: CommunityPreset?

    var body: some View {
        let shown: [CommunityPreset] = showsControls
            ? PresetQuery.apply(presets, filter: filter, sort: sort, likedIds: library.likedPresetIds)
            : presets

        VStack(alignment: .leading, spacing: 12) {
            if showsControls {
                controls(count: shown.count)
            }
            if shown.isEmpty {
                ContentUnavailableView(emptyTitle, systemImage: "slider.horizontal.3", description: Text(emptyMessage))
            } else {
                SurfaceList(items: shown) { preset in
                    PresetRow(
                        preset: preset,
                        showsArtist: showsArtist,
                        isLiked: library.isLiked(presetId: preset.id),
                        isActive: player.activePreset?.id == preset.id,
                        onPlay: { play(preset) },
                        onLike: { library.toggleLike(presetId: preset.id) }
                    )
                    .contextMenu {
                        if let onDelete, preset.id.hasPrefix(MinePresetID.prefix) {
                            Button(role: .destructive) {
                                onDelete(preset)
                            } label: {
                                Label("Eliminar preset", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .alert(
            "Necesitas esta pista en tu biblioteca",
            isPresented: Binding(get: { missingPreset != nil }, set: { if !$0 { missingPreset = nil } }),
            presenting: missingPreset
        ) { _ in
            Button("Importar") {
                player.isNowPlayingPresented = false
                navigation.openImport()
            }
            Button("Cancelar", role: .cancel) {}
        } message: { preset in
            Text("Importa «\(preset.track.title)» de \(preset.track.artist) para aplicarle este preset. Slow Mode nunca descarga ni comparte audio.")
        }
    }

    /// Orden en su propia fila (a la derecha) y chips de filtro a todo el ancho debajo.
    private func controls(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(count == 1 ? "1 preset" : "\(count) presets")
                    .textStyle(.caption)
                    .monospacedDigit()
                Spacer(minLength: 8)
                Menu {
                    Picker("Orden", selection: $sort) {
                        ForEach(PresetSort.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sort.title)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .padding(.vertical, 4)
                    .contentShape(.rect)
                }
                .accessibilityLabel("Ordenar")
                .accessibilityValue(sort.title)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(PresetFilter.allCases) { option in
                            Chip(title: option.title, isSelected: filter == option) {
                                filter = option
                            }
                        }
                    }
                }
            }
        }
    }

    private func play(_ preset: CommunityPreset) {
        if let track = localLibrary.match(preset.track) ?? store.catalog.localTrack(for: preset) {
            player.apply(preset, to: track)
        } else {
            missingPreset = preset
        }
    }
}
