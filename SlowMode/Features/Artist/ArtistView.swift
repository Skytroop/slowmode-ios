import SwiftUI

struct ArtistView: View {
    let artistId: String

    @Environment(CatalogStore.self) private var store: CatalogStore
    @Environment(PlayerController.self) private var player: PlayerController
    @State private var section: ArtistSection = .top

    enum ArtistSection: Hashable {
        case top, presets
    }

    var body: some View {
        let catalog: SampleCatalog = store.catalog

        Group {
            if let artist = catalog.artist(id: artistId) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ArtistHeader(artist: artist) {
                            playTop(artist, catalog: catalog)
                        }

                        Picker("Sección", selection: $section) {
                            Text("Más escuchadas").tag(ArtistSection.top)
                            Text("Presets de la comunidad").tag(ArtistSection.presets)
                        }
                        .pickerStyle(.segmented)

                        switch section {
                        case .top:
                            topTracks(artist, catalog: catalog)
                        case .presets:
                            PresetListSection(
                                presets: catalog.presets(byArtist: artist.id),
                                showsArtist: false,
                                emptyMessage: "Nadie ha compartido presets de \(artist.name) todavía."
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            } else {
                ContentUnavailableView("Artista no encontrado", systemImage: "person.slash")
            }
        }
        .background(AmbientBackground())
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func topTracks(_ artist: CatalogArtist, catalog: SampleCatalog) -> some View {
        let tracks: [CatalogTrack] = catalog.tracks(byArtist: artist.id)
        if tracks.isEmpty {
            ContentUnavailableView("Sin canciones", systemImage: "music.note", description: Text("No tienes canciones de \(artist.name) en este iPhone."))
        } else {
            let colors: ArtworkColors = ArtworkColors.forArtist(artist.id, in: catalog)
            SurfaceList(items: Array(tracks.enumerated()).map { IndexedTrack(index: $0.offset, track: $0.element) }) { item in
                Button {
                    player.play(item.track, in: tracks, from: artist.name)
                    player.isNowPlayingPresented = true
                } label: {
                    TrackRow(
                        title: item.track.title,
                        subtitle: "\(item.track.plays) reproducciones · \(SlowModeFormat.duration(Double(item.track.duration)))",
                        artwork: colors,
                        rank: item.index + 1,
                        isCurrent: player.currentTrack?.id == item.track.id
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func playTop(_ artist: CatalogArtist, catalog: SampleCatalog) {
        let tracks: [CatalogTrack] = catalog.tracks(byArtist: artist.id)
        guard let first = tracks.first else { return }
        player.play(first, in: tracks, from: artist.name)
    }
}

struct IndexedTrack: Identifiable {
    let index: Int
    let track: CatalogTrack
    var id: String { track.id }
}

private struct ArtistHeader: View {
    let artist: CatalogArtist
    let onPlay: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            InitialsAvatar(
                initials: artist.initials,
                background: Color(hex: artist.color),
                foreground: Color(hex: artist.onColor),
                size: 104
            )
            Text(artist.name)
                .textStyle(.screenTitle)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Pill(text: artist.genre, background: Palette.ink.opacity(0.1), foreground: Palette.ink)
            Text("\(artist.plays) reproducciones · nº \(artist.rank) más escuchado")
                .font(.footnote.weight(.medium))
                .monospacedDigit()
            Button(action: onPlay) {
                Label("Reproducir", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 28)
                    .frame(minHeight: 52)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(Palette.ink).interactive(), in: .capsule)
            .accessibilityLabel("Reproducir \(artist.name)")
        }
        .foregroundStyle(Palette.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Palette.periwinkleGradient, in: .rect(cornerRadius: Radius.card))
    }
}
