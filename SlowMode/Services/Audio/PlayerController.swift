import Foundation
import Observation
import UIKit

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

/// Estado de reproducción y cola. Las pistas importadas suenan con el motor de audio;
/// las de ejemplo (sin archivo) simulan el avance del tiempo.
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
    var slow: SlowSettings = SlowSettings() {
        didSet {
            if slow != oldValue { settingsChanged() }
        }
    }
    /// Preset de la comunidad aplicado a la pista actual, si lo hay.
    private(set) var activePreset: CommunityPreset?
    var isShuffling: Bool = false
    var repeatMode: RepeatMode = .off
    var isNowPlayingPresented: Bool = false
    private(set) var playbackError: String?
    /// Fragmento que se repite (segundos de la pista original). Se quita al cambiar de pista.
    private(set) var loopRange: ClosedRange<Double>?
    static let minimumLoopLength: Double = 1

    /// Devuelve el archivo de audio de una pista (solo las importadas tienen).
    @ObservationIgnored var fileURLProvider: (CatalogTrack) -> URL? = { _ in nil }
    @ObservationIgnored var artworkProvider: (CatalogTrack) -> UIImage? = { _ in nil }

    @ObservationIgnored private let engine: PlaybackEngine?
    @ObservationIgnored private let nowPlaying: NowPlayingService?
    @ObservationIgnored private var usesEngine: Bool = false
    @ObservationIgnored private var resumeAfterInterruption: Bool = false
    @ObservationIgnored private var ticker: Task<Void, Never>?
    private static let tickInterval: Double = 0.25

    init(engine: PlaybackEngine? = nil, nowPlaying: NowPlayingService? = nil) {
        self.engine = engine
        self.nowPlaying = nowPlaying
        engine?.onFinished = { [weak self] in self?.handleTrackEnd() }
        engine?.onInterruption = { [weak self] event in self?.handleInterruption(event) }
        nowPlaying?.register(RemoteCommandHandlers(
            play: { [weak self] in Task { @MainActor in self?.resume() } },
            pause: { [weak self] in Task { @MainActor in self?.pause() } },
            toggle: { [weak self] in Task { @MainActor in self?.togglePlayPause() } },
            next: { [weak self] in Task { @MainActor in self?.next() } },
            previous: { [weak self] in Task { @MainActor in self?.previous() } },
            seek: { [weak self] seconds in Task { @MainActor in self?.seek(to: seconds) } }
        ))
    }

    var duration: Double { Double(currentTrack?.duration ?? 0) }

    /// Tiempo transcurrido tal como suena (estirado por el tempo).
    var displayedElapsed: Double { SlowModeMath.stretchedDuration(position, tempo: slow.effectiveTempo) }

    /// Duración tal como suena (3:34 a 0.85× → 4:12).
    var displayedDuration: Double { SlowModeMath.stretchedDuration(duration, tempo: slow.effectiveTempo) }

    /// `true` si la pista actual suena de verdad (archivo importado).
    var isPlayingRealAudio: Bool { usesEngine }

    var upNext: [CatalogTrack] {
        guard let index = currentIndex else { return [] }
        return Array(queue[(index + 1)...])
    }

    private var currentIndex: Int? {
        guard let current = currentTrack else { return nil }
        return queue.firstIndex { $0.id == current.id }
    }

    /// Deja una pista preparada (en pausa) si no hay ninguna, para que el minirreproductor tenga algo que mostrar.
    func prepareIfIdle(with tracks: [CatalogTrack], source: String) {
        guard currentTrack == nil, let first = tracks.first else { return }
        queue = tracks
        sourceTitle = source
        load(first)
        updateNowPlaying()
    }

    func play(_ track: CatalogTrack, in queue: [CatalogTrack], from source: String) {
        self.queue = queue.contains(where: { $0.id == track.id }) ? queue : [track]
        sourceTitle = source
        load(track)
        setPlaying(true)
    }

    /// Aplica un preset de la comunidad a la copia local de su pista y la reproduce.
    func apply(_ preset: CommunityPreset, to track: CatalogTrack) {
        slow = SlowSettings(
            isEnabled: true,
            tempo: SlowModeMath.clampTempo(preset.tempo),
            pitch: SlowModeMath.clampPitch(preset.pitch),
            reverb: SlowModeMath.clampReverb(preset.reverb),
            isLinked: preset.linked
        )
        play(track, in: [track], from: preset.track.artist)
        activePreset = preset
    }

    func togglePlayPause() {
        guard currentTrack != nil else { return }
        setPlaying(!isPlaying)
    }

    func resume() {
        if !isPlaying { togglePlayPause() }
    }

    func pause() {
        if isPlaying { setPlaying(false) }
    }

    func next() {
        advance(by: 1, wrapsAlways: true)
    }

    /// Vuelve al principio si han pasado más de 3 s; si no, a la pista anterior.
    func previous() {
        if position > 3 {
            seek(to: 0)
        } else {
            advance(by: -1, wrapsAlways: true)
        }
    }

    /// Con un fragmento activo, la posición se mantiene dentro de él.
    func seek(to seconds: Double) {
        var target: Double = min(max(seconds, 0), duration)
        if let loop = loopRange {
            target = min(max(target, loop.lowerBound), loop.upperBound)
        }
        position = target
        if usesEngine { engine?.seek(to: position) }
        updateNowPlaying()
    }

    /// Repite de `start` a `end` (segundos de la pista original). Devuelve `false` si el fragmento es demasiado corto.
    @discardableResult
    func setLoop(start: Double, end: Double) -> Bool {
        let lower: Double = min(max(start, 0), duration)
        let upper: Double = min(max(end, 0), duration)
        guard upper - lower >= Self.minimumLoopLength else { return false }
        loopRange = lower...upper
        if position < lower || position >= upper { position = lower }
        if usesEngine { engine?.setLoop(loopRange) }
        updateNowPlaying()
        return true
    }

    func clearLoop() {
        guard loopRange != nil else { return }
        loopRange = nil
        if usesEngine { engine?.setLoop(nil) }
    }

    func setSlowMode(enabled: Bool) {
        slow.isEnabled = enabled
        if !enabled { activePreset = nil }
    }

    func cycleRepeatMode() {
        repeatMode = repeatMode.next
    }

    func dismissError() {
        playbackError = nil
    }

    /// Avanza el reloj `seconds` de tiempo real. Con audio real, lee la posición del motor.
    func tick(seconds: Double) {
        guard isPlaying, currentTrack != nil else { return }
        if usesEngine, let engine {
            position = min(engine.currentTime, duration)
            return
        }
        position += seconds * slow.effectiveTempo
        if let loop = loopRange, position >= loop.upperBound {
            position = loop.lowerBound
            return
        }
        if position >= duration {
            handleTrackEnd()
        }
    }

    // MARK: - Privado

    private func load(_ track: CatalogTrack) {
        if currentTrack?.id != track.id { activePreset = nil }
        currentTrack = track
        position = 0
        loopRange = nil
        usesEngine = false
        guard let engine else { return }
        guard let url = fileURLProvider(track) else {
            engine.stop()
            return
        }
        do {
            try engine.load(url: url)
            engine.apply(slow.engineParameters)
            usesEngine = true
        } catch {
            engine.stop()
            playbackError = "No se pudo abrir «\(track.title)». Puede que el archivo se haya borrado o esté dañado."
        }
    }

    private func handleTrackEnd() {
        if repeatMode == .one {
            seek(to: 0)
            return
        }
        guard let index = currentIndex else {
            setPlaying(false)
            return
        }
        let isLast: Bool = index == queue.count - 1
        if isLast && repeatMode == .off && !isShuffling {
            setPlaying(false)
            position = duration
            updateNowPlaying()
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
        let wasPlaying: Bool = isPlaying
        load(queue[target])
        if wasPlaying {
            setPlaying(true)
        } else {
            updateNowPlaying()
        }
    }

    private func setPlaying(_ playing: Bool) {
        if usesEngine, let engine {
            if playing {
                do {
                    try engine.play()
                } catch {
                    playbackError = "No se pudo iniciar el audio."
                    isPlaying = false
                    stopTicker()
                    updateNowPlaying()
                    return
                }
            } else {
                engine.pause()
            }
        }
        isPlaying = playing
        if playing { startTicker() } else { stopTicker() }
        updateNowPlaying()
    }

    private func settingsChanged() {
        if usesEngine { engine?.apply(slow.engineParameters) }
        updateNowPlaying()
    }

    private func handleInterruption(_ event: AudioInterruption) {
        switch event {
        case .began:
            if isPlaying {
                resumeAfterInterruption = true
                setPlaying(false)
            }
        case .ended(let shouldResume):
            if shouldResume && resumeAfterInterruption { setPlaying(true) }
            resumeAfterInterruption = false
        case .outputLost:
            resumeAfterInterruption = false
            if isPlaying { setPlaying(false) }
        }
    }

    private func updateNowPlaying() {
        guard let nowPlaying else { return }
        guard let track = currentTrack else {
            nowPlaying.clear()
            return
        }
        nowPlaying.update(
            NowPlayingInfo(
                title: track.title,
                artist: track.artist,
                album: track.album,
                duration: duration,
                elapsed: position,
                rate: isPlaying ? slow.effectiveTempo : 0
            ),
            artwork: artworkProvider(track)
        )
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

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }
}
