import SwiftUI

/// Reproduciendo, a pantalla completa.
struct NowPlayingView: View {
    @Environment(PlayerController.self) private var player: PlayerController
    @Environment(CatalogStore.self) private var store: CatalogStore
    @Environment(LibraryStore.self) private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool
    @State private var isPanelExpanded: Bool = false
    @State private var showsQueue: Bool = false
    @State private var showsAddToPlaylist: Bool = false
    @State private var showsTrackPresets: Bool = false

    var body: some View {
        let catalog: SampleCatalog = store.catalog

        ZStack {
            if let track = player.currentTrack {
                let colors: ArtworkColors = ArtworkColors.forArtist(track.artistId, in: catalog)
                AmbientBackground(
                    intensity: .player,
                    colors: [colors.background, Palette.pinkEnd, colors.background],
                    isMoving: player.isPlaying
                )
                ScrollView {
                    VStack(spacing: 22) {
                        topBar
                        TrackArtwork(colors: colors, size: isPanelExpanded ? 168 : 300, cornerRadius: Radius.card)
                            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
                            .animation(reduceMotion ? nil : .spring(duration: 0.45), value: isPanelExpanded)
                        titleBlock(track)
                        progress
                        transport
                        outputRow
                        SlowModePanel(
                            isExpanded: $isPanelExpanded,
                            trackDuration: player.duration,
                            presetCount: catalog.presets(forTrack: track).count,
                            onShowPresets: { showsTrackPresets = true }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .sheet(isPresented: $showsTrackPresets) {
                    TrackPresetsSheet(track: track)
                }
            } else {
                ContentUnavailableView("Nada sonando", systemImage: "music.note")
                    .overlay(alignment: .topLeading) { closeButton.padding(20) }
            }
        }
        .foregroundStyle(Palette.textPrimary)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showsQueue) { QueueSheet() }
        .sheet(isPresented: $showsAddToPlaylist) { AddToPlaylistSheet() }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.down")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Cerrar")
    }

    private var topBar: some View {
        HStack {
            closeButton
            Spacer()
            VStack(spacing: 2) {
                Text("Reproduciendo desde")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                Text(player.sourceTitle)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.top, 8)
    }

    private func subtitle(for track: CatalogTrack) -> String {
        if let preset = player.activePreset {
            return "\(track.artist) · \(preset.name) de @\(preset.creator.handle)"
        }
        switch track.origin {
        case .localFile: return "\(track.artist) · Archivo local"
        case .originalUpload: return "\(track.artist) · Original subido"
        }
    }

    private func titleBlock(_ track: CatalogTrack) -> some View {
        let isLiked: Bool = library.isLiked(trackId: track.id)

        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text(track.title)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                Text(subtitle(for: track))
                    .textStyle(.caption)
                    .lineLimit(2)
                if let summary = player.slow.summary {
                    Pill(text: summary, background: Palette.periwinkle, foreground: Palette.ink)
                        .accessibilityLabel("Slow Mode: \(summary)")
                }
            }
            Spacer(minLength: 8)
            Button {
                showsAddToPlaylist = true
            } label: {
                Image(systemName: "text.badge.plus")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Añadir a playlist")

            Button {
                library.toggleLike(trackId: track.id)
            } label: {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundStyle(isLiked ? Palette.pink : Palette.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Me gusta")
            .accessibilityAddTraits(isLiked ? .isSelected : [])
        }
    }

    private var progress: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(get: { player.position }, set: { player.seek(to: $0) }),
                in: 0...max(player.duration, 1)
            ) {
                Text("Posición")
            }
            .accessibilityValue("\(SlowModeFormat.duration(player.displayedElapsed)) de \(SlowModeFormat.duration(player.displayedDuration))")
            HStack {
                Text(SlowModeFormat.duration(player.displayedElapsed))
                Spacer()
                Text(SlowModeFormat.duration(player.displayedDuration))
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(Palette.textSecondary)
            .accessibilityHidden(true)
        }
    }

    private var transport: some View {
        HStack {
            Button {
                player.isShuffling.toggle()
            } label: {
                Image(systemName: "shuffle")
                    .foregroundStyle(player.isShuffling ? Palette.periwinkle : Palette.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Aleatorio")
            .accessibilityValue(player.isShuffling ? "Activado" : "Desactivado")

            Spacer()

            Button {
                player.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .frame(width: 52, height: 52)
            }
            .accessibilityLabel("Anterior")

            Spacer()

            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 76, height: 76)
            }
            .glassEffect(.regular.tint(Palette.periwinkle).interactive(), in: .circle)
            .accessibilityLabel(player.isPlaying ? "Pausa" : "Reproducir")

            Spacer()

            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .frame(width: 52, height: 52)
            }
            .accessibilityLabel("Siguiente")

            Spacer()

            Button {
                player.cycleRepeatMode()
            } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .foregroundStyle(player.repeatMode == .off ? Palette.textPrimary : Palette.periwinkle)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Repetir")
            .accessibilityValue(player.repeatMode.accessibilityValue)
        }
        .buttonStyle(.plain)
    }

    private var outputRow: some View {
        HStack {
            RoutePickerButton()
                .frame(width: 44, height: 44)
                .accessibilityLabel("Salida de audio")
            Spacer()
            Button {
                showsQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("A continuación")
        }
    }
}
