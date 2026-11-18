import SwiftUI

/// Reproduciendo, a pantalla completa.
struct NowPlayingView: View {
    @Environment(PlayerController.self) private var player: PlayerController
    @Environment(CatalogStore.self) private var store: CatalogStore
    @Environment(LocalLibrary.self) private var localLibrary: LocalLibrary
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool
    @State private var isPanelExpanded: Bool = false
    @State private var showsQueue: Bool = false
    @State private var showsAddToPlaylist: Bool = false
    @State private var showsTrackPresets: Bool = false
    @State private var showsLoop: Bool = false
    @State private var toast: String?

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
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 22) {
                            topBar
                                .id(Self.topAnchor)
                            artwork(track, colors: colors) {
                                // Tocar la portada: plegar el panel y volver arriba. Slow Mode sigue activo.
                                animate { isPanelExpanded = false }
                                animate { proxy.scrollTo(Self.topAnchor, anchor: .top) }
                            }
                            titleBlock(track)
                            SlowPresetBar(track: track)
                            progress
                            transport
                            outputRow
                            SlowModePanel(
                                isExpanded: $isPanelExpanded,
                                trackDuration: player.duration,
                                presetCount: catalog.presets(forTrack: track).count,
                                onShowPresets: { showsTrackPresets = true },
                                onSaved: { name in showToast("Preset «\(name)» guardado") }
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                    .scrollIndicators(.hidden)
                }
                .sheet(isPresented: $showsTrackPresets) {
                    TrackPresetsSheet(track: track)
                }
                .sheet(isPresented: $showsLoop) {
                    LoopSheet(
                        start: player.loopRange?.lowerBound ?? player.position.rounded(.down),
                        end: player.loopRange?.upperBound ?? min(player.position.rounded(.down) + 10, player.duration)
                    )
                }
            } else {
                ContentUnavailableView("Nada sonando", systemImage: "music.note")
                    .overlay(alignment: .topLeading) { closeButton.padding(20) }
            }
        }
        .foregroundStyle(Palette.textPrimary)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.nowPlayingView)
        .preferredColorScheme(.dark)
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 18)
                    .frame(minHeight: 40)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 24)
                    .transition(.opacity)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .sheet(isPresented: $showsQueue) { QueueSheet() }
        .sheet(isPresented: $showsAddToPlaylist) { AddToPlaylistSheet() }
    }

    private static let topAnchor: String = "nowPlayingTop"

    private func animate(_ change: () -> Void) {
        if reduceMotion {
            change()
        } else {
            withAnimation(.spring(duration: 0.45)) { change() }
        }
    }

    private func showToast(_ message: String) {
        animate { toast = message }
        AccessibilityNotification.Announcement(message).post()
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if toast == message { animate { toast = nil } }
        }
    }

    /// Portada (se encoge con el panel abierto). Con Slow Mode activo lleva una etiqueta con los ajustes.
    private func artwork(_ track: CatalogTrack, colors: ArtworkColors, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            TrackArtwork(
                colors: colors,
                image: localLibrary.artwork(for: track.id),
                size: isPanelExpanded ? 168 : 300,
                cornerRadius: Radius.card
            )
            .overlay(alignment: .bottomLeading) {
                if let badge = SlowModeFormat.badge(for: player.slow) {
                    Pill(text: badge, background: Palette.periwinkle, foreground: Palette.ink)
                        .padding(12)
                        .opacity(isPanelExpanded ? 0 : 1)
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .spring(duration: 0.45), value: isPanelExpanded)
        .accessibilityLabel("Portada de \(track.title)")
        .accessibilityValue(SlowModeFormat.spokenBadge(for: player.slow) ?? "Sin Slow Mode")
        .accessibilityHint(isPanelExpanded ? "Amplía la portada y pliega el panel" : "")
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.down")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityIdentifier(AccessibilityID.nowPlayingClose)
        .accessibilityLabel("Cerrar Reproduciendo")
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
                if player.isSleepTimerActive {
                    // Se refresca cada segundo aunque la música esté en pausa.
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        if let status = sleepTimerStatus {
                            Label(status, systemImage: "moon.zzz.fill")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(Palette.periwinkle)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .accessibilityElement(children: .combine)
            Spacer()
            sleepTimerButton
        }
        .padding(.top, 8)
    }

    /// "12:30" o "Al terminar la pista" mientras el temporizador está activo.
    private var sleepTimerStatus: String? {
        if let remaining = player.sleepTimerRemaining {
            return SlowModeFormat.duration(remaining)
        }
        return player.stopsAtTrackEnd ? "Al terminar la pista" : nil
    }

    private var sleepTimerSpokenValue: String {
        if let remaining = player.sleepTimerRemaining {
            return "Se detiene en \(SlowModeFormat.spokenDuration(remaining))"
        }
        return player.stopsAtTrackEnd ? "Se detiene al terminar la pista" : "Desactivado"
    }

    /// Temporizador de apagado: pausa la música tras un tiempo o al terminar la pista.
    private var sleepTimerButton: some View {
        Menu {
            Section("Detener la música") {
                ForEach(PlayerController.sleepTimerOptions, id: \.self) { minutes in
                    Button("\(minutes) minutos") {
                        player.setSleepTimer(minutes: minutes)
                        showToast("Se detendrá en \(minutes) minutos")
                    }
                }
                Button("Al terminar la pista") {
                    player.setSleepTimerAtTrackEnd()
                    showToast("Se detendrá al terminar la pista")
                }
            }
            if player.isSleepTimerActive {
                Button("Desactivar temporizador", systemImage: "xmark", role: .destructive) {
                    player.cancelSleepTimer()
                    showToast("Temporizador desactivado")
                }
            }
        } label: {
            Image(systemName: player.isSleepTimerActive ? "moon.zzz.fill" : "moon.zzz")
                .font(.body.weight(.semibold))
                .foregroundStyle(player.isSleepTimerActive ? Palette.periwinkle : Palette.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityIdentifier(AccessibilityID.nowPlayingSleepTimer)
        .accessibilityLabel("Temporizador de apagado")
        .accessibilityValue(sleepTimerSpokenValue)
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
        let isLiked: Bool = localLibrary.isLiked(catalogId: track.id)

        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text(track.title)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                Text(subtitle(for: track))
                    .textStyle(.caption)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button {
                showsAddToPlaylist = true
            } label: {
                Image(systemName: "text.badge.plus")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Añadir a playlist")

            Button {
                localLibrary.toggleLike(catalogId: track.id)
            } label: {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundStyle(isLiked ? Palette.pink : Palette.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
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
            .accessibilityIdentifier(AccessibilityID.nowPlayingProgress)
            .accessibilityValue("\(SlowModeFormat.spokenDuration(player.displayedElapsed)) de \(SlowModeFormat.spokenDuration(player.displayedDuration))")
            HStack {
                Text(SlowModeFormat.duration(player.displayedElapsed))
                Spacer()
                Text(SlowModeFormat.duration(player.displayedDuration))
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(Palette.textSecondary)
            .accessibilityHidden(true)

            if let loop = player.loopRange {
                loopRegion(loop)
                HStack(spacing: 8) {
                    Button {
                        showsLoop = true
                    } label: {
                        Label(
                            "Fragmento \(SlowModeFormat.duration(loop.lowerBound))–\(SlowModeFormat.duration(loop.upperBound))",
                            systemImage: "repeat"
                        )
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 32)
                        .background(Palette.periwinkle, in: .capsule)
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edita el fragmento que se repite")

                    Button {
                        player.clearLoop()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Palette.textSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Quitar fragmento")
                    Spacer()
                }
            }
        }
    }

    /// Marca bajo la barra la zona que se repite.
    private func loopRegion(_ loop: ClosedRange<Double>) -> some View {
        let total: Double = max(player.duration, 1)
        return GeometryReader { proxy in
            Capsule()
                .fill(Palette.periwinkle)
                .frame(width: max(4, proxy.size.width * (loop.upperBound - loop.lowerBound) / total), height: 4)
                .offset(x: proxy.size.width * loop.lowerBound / total)
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }

    private var transport: some View {
        HStack {
            Button {
                player.isShuffling.toggle()
            } label: {
                Image(systemName: "shuffle")
                    .foregroundStyle(player.isShuffling ? Palette.periwinkle : Palette.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
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
                    .contentShape(.rect)
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
            .accessibilityIdentifier(AccessibilityID.nowPlayingPlayPause)
            .accessibilityLabel(player.isPlaying ? "Pausa" : "Reproducir")

            Spacer()

            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .frame(width: 52, height: 52)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Siguiente")

            Spacer()

            Button {
                player.cycleRepeatMode()
            } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .foregroundStyle(player.repeatMode == .off ? Palette.textPrimary : Palette.periwinkle)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
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
                .contentShape(.rect)
                .accessibilityLabel("Salida de audio")
            Spacer()
            Button {
                showsLoop = true
            } label: {
                Label("Fragmento", systemImage: "arrow.left.and.right")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(player.loopRange == nil ? Palette.textPrimary : Palette.periwinkle)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.nowPlayingLoop)
            .accessibilityLabel("Repetir fragmento")
            .accessibilityValue(player.loopRange == nil ? "Desactivado" : "Activado")
            Spacer()
            Button {
                showsQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.nowPlayingQueue)
            .accessibilityLabel("A continuación")
        }
    }
}
