import SwiftUI

/// Minirreproductor en `.tabViewBottomAccessory`. El sistema le pone el cristal.
struct MiniPlayerView: View {
    @Environment(PlayerController.self) private var player: PlayerController
    @Environment(CatalogStore.self) private var store: CatalogStore

    var body: some View {
        if let track = player.currentTrack {
            let colors: ArtworkColors = ArtworkColors.forArtist(track.artistId, in: store.catalog)
            let subtitle: String = player.activePreset.map { "@\($0.creator.handle)" } ?? track.artist

            HStack(spacing: 10) {
                Button {
                    player.isNowPlayingPresented = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "music.note")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(colors.foreground)
                            .frame(width: 32, height: 32)
                            .background(colors.background, in: .circle)
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
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(track.title), \(subtitle)")
                .accessibilityHint("Abre Reproduciendo")
                .accessibilityAddTraits(.isButton)

                if player.slow.isEnabled {
                    Button {
                        player.setSlowMode(enabled: false)
                    } label: {
                        Pill(text: SlowModeFormat.tempo(player.slow.tempo), background: Palette.periwinkle, foreground: Palette.ink)
                            .frame(minHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Slow Mode a \(SlowModeFormat.tempo(player.slow.tempo))")
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
