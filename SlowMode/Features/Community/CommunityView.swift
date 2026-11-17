import SwiftUI

struct CommunityView: View {
    @Environment(CatalogStore.self) private var store: CatalogStore
    @Environment(PlayerController.self) private var player: PlayerController

    var body: some View {
        let catalog: SampleCatalog = store.catalog

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Mezclas originales, oyentes y presets de Slow Mode.")
                    .textStyle(.caption)

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Mezclas originales")
                    if catalog.mixes.isEmpty {
                        ContentUnavailableView("Sin mezclas", systemImage: "waveform", description: Text("Aún nadie ha subido mezclas."))
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(catalog.mixes) { mix in
                                    MixCard(mix: mix) { play(mix, catalog: catalog) }
                                }
                            }
                        }
                        .scrollClipDisabled()
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Oyentes como tú")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(catalog.listeners) { listener in
                                ListenerCard(listener: listener)
                            }
                        }
                    }
                    .scrollClipDisabled()
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Presets de Slow Mode") {
                        NavigationLink(value: AppRoute.allPresets) {
                            Text("Ver todos")
                                .font(.subheadline.weight(.medium))
                                .frame(minHeight: 44)
                        }
                    }
                    Text("Recetas de tempo, tono y reverb para pistas que tienes. No se comparte audio.")
                        .textStyle(.caption)
                    PresetListSection(
                        presets: PresetQuery.top(catalog.presets, count: 6),
                        showsArtist: true,
                        showsControls: false
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(AmbientBackground())
        .navigationTitle("Comunidad")
    }

    private func play(_ mix: CatalogMix, catalog: SampleCatalog) {
        guard let id = mix.previewTrackId, let track = catalog.track(id: id) else { return }
        player.play(track, in: [track], from: "\(mix.title) de @\(mix.creator)")
    }
}

private struct MixCard: View {
    let mix: CatalogMix
    let onPlay: () -> Void

    private var fill: AnyShapeStyle {
        switch mix.style {
        case .periwinkle: return AnyShapeStyle(Palette.periwinkleGradient)
        case .pink: return AnyShapeStyle(Palette.pinkGradient)
        case .sand: return AnyShapeStyle(Palette.sand)
        case .dark: return AnyShapeStyle(Color(hex: "#1E1E23"))
        }
    }

    private var ink: Color { mix.style == .dark ? Palette.periwinkle : Palette.ink }

    var body: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "waveform")
                    .font(.title3.weight(.medium))
                Spacer(minLength: 0)
                Text(mix.title)
                    .font(.headline)
                    .lineLimit(2)
                Text("@\(mix.creator) · \(mix.minutes) min")
                    .font(.footnote)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .foregroundStyle(ink)
            .padding(16)
            .frame(width: 164, height: 164, alignment: .topLeading)
            .background(fill, in: .rect(cornerRadius: Radius.card))
            .contentShape(.rect(cornerRadius: Radius.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mezcla original \(mix.title) de @\(mix.creator), \(mix.minutes) minutos")
    }
}

private struct ListenerCard: View {
    let listener: CatalogListener
    @Environment(LibraryStore.self) private var library: LibraryStore
    @Environment(\.theme) private var theme: Theme

    var body: some View {
        let following: Bool = library.isFollowing(listener.id)

        VStack(spacing: 8) {
            InitialsAvatar(
                initials: listener.initials,
                background: Color(hex: listener.color),
                foreground: Color(hex: listener.onColor),
                size: 64
            )
            Text(listener.name)
                .textStyle(.body)
                .lineLimit(1)
            Text("\(listener.affinity) % de afinidad")
                .textStyle(.caption)
                .monospacedDigit()
            if following {
                Button("Siguiendo") { library.toggleFollow(listener.id) }
                    .buttonStyle(.glass)
                    .accessibilityHint("Deja de seguir a \(listener.name)")
            } else {
                Button("Seguir") { library.toggleFollow(listener.id) }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.periwinkle)
                    .foregroundStyle(Palette.ink)
            }
        }
        .frame(width: 140)
        .padding(.vertical, 16)
        .background(theme.surface, in: .rect(cornerRadius: Radius.list))
    }
}

struct AllPresetsView: View {
    @Environment(CatalogStore.self) private var store: CatalogStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recetas de tempo, tono y reverb para pistas que tienes. No se comparte audio.")
                    .textStyle(.caption)
                PresetListSection(presets: store.catalog.presets, showsArtist: true)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(AmbientBackground())
        .navigationTitle("Presets")
    }
}
