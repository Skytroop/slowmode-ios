import Foundation
import Observation

enum RepeatMode: String, CaseIterable, Sendable {
    case off, all, one

    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }

    var accessibilityValue: String {
        switch self {
        case .off: return "No"
        case .all: return "Todo"
        case .one: return "Una"
        }
    }
}

/// Estado de reproducción. En la Fase 1 no suena nada: simula el avance del tiempo.
/// En la Fase 2 delega en `AudioEngineService` manteniendo esta interfaz.
@MainActor
@Observable
final class PlayerController {
    private(set) var currentTrack: CatalogTrack?
    private(set) var queue: [CatalogTrack] = []
    /// "Reproduciendo desde …"
    private(set) var sourceTitle: String = ""
    private(set) var isPlaying: Bool = false
    /// Posición en segundos dentro de la pista original (sin estirar).
    private(set) var position: Double = 0
    var slow: SlowSettings = SlowSettings()
    /// Preset de la comunidad aplicado a la pista actual, si lo hay.
    private(set) var activePreset: CommunityPreset?
    var isShuffling: Bool = false
    var repeatMode: RepeatMode = .off
    var isNowPlayingPresented: Bool = false

    @ObservationIgnored private var ticker: Task<Void, Never>?
    private static let tickInterval: Double = 0.25

    init() {}

    var duration: Double { Double(currentTrack?.duration ?? 0) }

    /// Tiempo transcurrido tal como suena (estirado por el tempo).
    var displayedElapsed: Double { SlowModeMath.stretchedDuration(position, tempo: slow.effectiveTempo) }

    /// Duración tal como suena (3:34 a 0.85× → 4:12).
    var displayedDuration: Double { SlowModeMath.stretchedDuration(duration, tempo: slow.effectiveTempo) }

    var upNext: [CatalogTrack] {
        guard let index = currentIndex else { return [] }
        return Array(queue[(index + 1)...])
    }

    private var currentIndex: Int? {
        guard let current = currentTrack else { return nil }
        return queue.firstIndex { $0.id == current.id }
    }

    /// Deja una pista preparada (en pausa) si no hay ninguna. Para que el minirreproductor tenga algo que mostrar.
    func prepareIfIdle(with catalog: SampleCatalog) {
        guard currentTrack == nil else { return }
        let artistId: String = catalog.home.discover.centerArtistId
        let tracks: [CatalogTrack] = catalog.tracks(byArtist: artistId)
        guard let first = tracks.first else { return }
        currentTrack = first
        queue = tracks
        sourceTitle = catalog.artist(id: artistId)?.name ?? first.artist
        position = min(47, Double(first.duration))
    }

    func play(_ track: CatalogTrack, in queue: [CatalogTrack], from source: String) {
        self.queue = queue.contains(where: { $0.id == track.id }) ? queue : [track]
        sourceTitle = source
        load(track)
        setPlaying(true)
    }

    /// Aplica un preset de la comunidad a la copia local de su pista y la reproduce.
    func apply(_ preset: CommunityPreset, to track: CatalogTrack) {
        play(track, in: [track], from: preset.track.artist)
        slow = SlowSettings(
            isEnabled: true,
            tempo: SlowModeMath.clampTempo(preset.tempo),
            pitch: SlowModeMath.clampPitch(preset.pitch),
            reverb: SlowModeMath.clampReverb(preset.reverb),
            isLinked: preset.linked
        )
        activePreset = preset
    }

    func togglePlayPause() {
        guard currentTrack != nil else { return }
        setPlaying(!isPlaying)
    }

    func next() {
        advance(by: 1, wrapsAlways: true)
    }

    /// Vuelve al principio si han pasado más de 3 s; si no, a la pista anterior.
    func previous() {
        if position > 3 {
            position = 0
        } else {
            advance(by: -1, wrapsAlways: true)
        }
    }

    func seek(to seconds: Double) {
        position = min(max(seconds, 0), duration)
    }

    func setSlowMode(enabled: Bool) {
        slow.isEnabled = enabled
        if !enabled { activePreset = nil }
    }

    func cycleRepeatMode() {
        repeatMode = repeatMode.next
    }

    /// Avanza el reloj simulado `seconds` de tiempo real.
    func tick(seconds: Double) {
        guard isPlaying, currentTrack != nil else { return }
        position += seconds * slow.effectiveTempo
        if position >= duration {
            handleTrackEnd()
        }
    }

    // MARK: - Privado

    private func load(_ track: CatalogTrack) {
        if currentTrack?.id != track.id { activePreset = nil }
        currentTrack = track
        position = 0
    }

    private func handleTrackEnd() {
        if repeatMode == .one {
            position = 0
            return
        }
        guard let index = currentIndex else {
            setPlaying(false)
            return
        }
        let isLast: Bool = index == queue.count - 1
        if isLast && repeatMode == .off && !isShuffling {
            position = duration
            setPlaying(false)
        } else {
            advance(by: 1, wrapsAlways: true)
        }
    }

    private func advance(by delta: Int, wrapsAlways: Bool) {
        guard let index = currentIndex, !queue.isEmpty else { return }
        var target: Int = index + delta
        if isShuffling && queue.count > 1 {
            let offset: Int = Int.random(in: 1..<queue.count)
            target = (index + offset) % queue.count
        } else if target < 0 || target >= queue.count {
            guard wrapsAlways || repeatMode == .all else { return }
            target = (target + queue.count) % queue.count
        }
        load(queue[target])
    }

    private func setPlaying(_ playing: Bool) {
        isPlaying = playing
        if playing {
            startTicker()
        } else {
            ticker?.cancel()
            ticker = nil
        }
    }

    private func startTicker() {
        guard ticker == nil else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, !Task.isCancelled else { return }
                self.tick(seconds: Self.tickInterval)
            }
        }
    }
}
