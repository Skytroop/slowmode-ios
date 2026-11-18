import SwiftUI

/// Minirreproductor en `.tabViewBottomAccessory`. El sistema le pone el cristal.
struct MiniPlayerView: View {
    @Environment(PlayerController.self) private var player: PlayerController
    @Environment(CatalogStore.self) private var store: CatalogStore
    @Environment(LocalLibrary.self) private var localLibrary: LocalLibrary

    var body: some View {
        if let track = player.currentTrack {
            let colors: ArtworkColors = ArtworkColors.forArtist(track.artistId, in: store.catalog)
            let subtitle: String = player.activePreset.map { "@\($0.creator.handle)" } ?? track.artist

            HStack(spacing: 10) {
                Button {
                    player.isNowPlayingPresented = true
                } label: {
                    HStack(spacing: 10) {
                        TrackArtwork(colors: colors, image: localLibrary.artwork(for: track.id), size: 32, cornerRadius: 16)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(track.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(Palette.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.miniPlayerOpen)
                .accessibilityLabel("\(track.title), \(subtitle)")
                .accessibilityHint("Abre Reproduciendo")

                if player.slow.isEnabled {
                    Button {
                        player.setSlowMode(enabled: false)
                    } label: {
                        Pill(text: SlowModeFormat.tempo(player.slow.tempo), background: Palette.periwinkle, foreground: Palette.ink)
                            .frame(minHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.miniPlayerSpeed)
                    .accessibilityLabel("Slow Mode, \(SlowModeFormat.spokenTempo(player.slow.tempo))")
                    .accessibilityHint("Desactiva Slow Mode")
                }

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.miniPlayerPlayPause)
                .accessibilityLabel(player.isPlaying ? "Pausa" : "Reproducir")
            }
            .padding(.horizontal, 12)
            .foregroundStyle(Palette.textPrimary)
        } else {
            Text("Nada sonando")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity)
        }
    }
}
