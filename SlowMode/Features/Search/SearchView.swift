import SwiftUI

struct SearchView: View {
    @Environment(CatalogStore.self) private var store: CatalogStore
    @Environment(PlayerController.self) private var player: PlayerController
    @State private var query: String = ""
    @State private var scope: SearchScope?
    @State private var recents: [String] = ["Luna Vale", "noche", "Paper Lanterns", "daycore"]

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                scopeChips
                if trimmedQuery.isEmpty {
                    BrowseGrid { term in query = term }
                    recentsSection
                } else {
                    results
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(AmbientBackground())
        .navigationTitle("Buscar")
        .searchable(text: $query, prompt: "Artistas, canciones, presets")
        .onSubmit(of: .search) { remember(trimmedQuery) }
    }

    private var scopeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(SearchScope.allCases) { option in
                        Chip(title: option.title, isSelected: scope == option) {
                            scope = scope == option ? nil : option
                        }
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    @ViewBuilder
    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Búsquedas recientes") {
                if !recents.isEmpty {
                    Button("Borrar") { recents.removeAll() }
                        .font(.subheadline.weight(.medium))
                        .frame(minHeight: 44)
                }
            }
            if recents.isEmpty {
                Text("Aquí aparecerán tus búsquedas.")
                    .textStyle(.caption)
            } else {
                SurfaceList(items: recents.map { RecentSearch(text: $0) }) { recent in
                    Button {
                        query = recent.text
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(Palette.textSecondary)
                                .accessibilityHidden(true)
                            Text(recent.text)
                                .textStyle(.body)
                            Spacer()
                        }
                        .frame(minHeight: 48)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        let catalog: SampleCatalog = store.catalog
        let found: [SearchResult] = SearchService.search(trimmedQuery, scope: scope, in: catalog)
        if found.isEmpty {
            ContentUnavailableView(
                "Sin resultados",
                systemImage: "magnifyingglass",
                description: Text("No hay nada que coincida con «\(trimmedQuery)».")
            )
        } else {
            SurfaceList(items: found) { result in
                resultRow(result, catalog: catalog)
            }
        }
    }

    @ViewBuilder
    private func resultRow(_ result: SearchResult, catalog: SampleCatalog) -> some View {
        switch result {
        case .artist(let artist):
            NavigationLink(value: AppRoute.artist(artist.id)) {
                EntityRow(
                    title: artist.name,
                    subtitle: "\(artist.genre) · \(artist.plays) reproducciones",
                    leading: .avatar(initials: artist.initials, colors: ArtworkColors(hexBackground: artist.color, hexForeground: artist.onColor)),
                    tag: "Artista"
                )
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded { remember(trimmedQuery) })
        case .track(let track):
            Button {
                remember(trimmedQuery)
                player.play(track, in: [track], from: "Buscar")
            } label: {
                TrackRow(
                    title: track.title,
                    subtitle: track.artist,
                    artwork: ArtworkColors.forArtist(track.artistId, in: catalog),
                    origin: track.origin,
                    trailing: "Canción"
                )
            }
            .buttonStyle(.plain)
        case .mix(let mix):
            Button {
                remember(trimmedQuery)
                if let id = mix.previewTrackId, let track = catalog.track(id: id) {
                    player.play(track, in: [track], from: "\(mix.title) de @\(mix.creator)")
                }
            } label: {
                EntityRow(
                    title: mix.title,
                    subtitle: "@\(mix.creator) · Mezcla original · \(mix.minutes) min",
                    leading: .gradient(AnyShapeStyle(Palette.periwinkleGradient), symbol: "waveform"),
                    tag: "Mezcla"
                )
            }
            .buttonStyle(.plain)
        case .preset(let preset):
            Button {
                remember(trimmedQuery)
                if let track = catalog.localTrack(for: preset) {
                    player.apply(preset, to: track)
                }
            } label: {
                EntityRow(
                    title: "\(preset.name) · \(preset.track.title)",
                    subtitle: "@\(preset.creator.handle) · " + (SlowModeFormat.summary(tempo: preset.tempo, pitch: preset.pitch, reverb: preset.reverb) ?? "Original"),
                    leading: .avatar(initials: preset.creator.initials, colors: ArtworkColors(hexBackground: preset.creator.color, hexForeground: preset.creator.onColor)),
                    tag: "Preset"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func remember(_ term: String) {
        guard !term.isEmpty else { return }
        recents.removeAll { $0.compare(term, options: .caseInsensitive) == .orderedSame }
        recents.insert(term, at: 0)
        if recents.count > 8 { recents.removeLast(recents.count - 8) }
    }
}

private struct RecentSearch: Identifiable {
    let text: String
    var id: String { text }
}

/// Tarjetas de género y estado de ánimo (sin texto en la búsqueda).
private struct BrowseGrid: View {
    let onPick: (String) -> Void

    private struct Card: Identifiable {
        let name: String
        let fill: AnyShapeStyle
        let ink: Color
        var id: String { name }
    }

    private var cards: [Card] {
        [
            Card(name: "Indie", fill: AnyShapeStyle(Palette.periwinkleGradient), ink: Palette.ink),
            Card(name: "Electrónica", fill: AnyShapeStyle(Palette.pinkGradient), ink: Palette.ink),
            Card(name: "Dream Pop", fill: AnyShapeStyle(Palette.sand), ink: Palette.ink),
            Card(name: "R&B", fill: AnyShapeStyle(Palette.cream), ink: Palette.ink),
            Card(name: "Noche", fill: AnyShapeStyle(Palette.indigo), ink: Palette.textPrimary),
            Card(name: "Día de lluvia", fill: AnyShapeStyle(Color(hex: "#C5D1F6")), ink: Palette.ink),
            Card(name: "Domingo por la mañana", fill: AnyShapeStyle(Palette.pink), ink: Palette.ink),
            Card(name: "Ralentizado", fill: AnyShapeStyle(Color(hex: "#17171C")), ink: Palette.textPrimary),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Explorar")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(cards) { card in
                    Button {
                        onPick(card.name)
                    } label: {
                        Text(card.name)
                            .font(.headline)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(card.ink)
                            .padding(14)
                            .frame(maxWidth: .infinity, minHeight: 88, alignment: .bottomLeading)
                            .background(card.fill, in: .rect(cornerRadius: Radius.list))
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.list)
                                    .strokeBorder(Color.white.opacity(card.ink == Palette.textPrimary ? 0.1 : 0), lineWidth: 1)
                            }
                            .contentShape(.rect(cornerRadius: Radius.list))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Busca \(card.name)")
                }
            }
        }
    }
}
