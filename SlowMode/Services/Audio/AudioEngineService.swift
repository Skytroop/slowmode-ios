import AVFoundation
import Foundation

/// Parámetros que recibe el motor de audio.
struct EngineParameters: Equatable, Sendable {
    /// `AVAudioUnitTimePitch.rate` (0.5–1.5).
    var rate: Float
    /// `AVAudioUnitTimePitch.pitch` en cents.
    var pitchCents: Float
    /// `AVAudioUnitReverb.wetDryMix` (0–100). 0 ⇒ reverb en bypass.
    var reverbMix: Float

    static let neutral: EngineParameters = EngineParameters(rate: 1, pitchCents: 0, reverbMix: 0)

    static func interpolate(_ from: EngineParameters, _ to: EngineParameters, _ t: Float) -> EngineParameters {
        EngineParameters(
            rate: from.rate + (to.rate - from.rate) * t,
            pitchCents: from.pitchCents + (to.pitchCents - from.pitchCents) * t,
            reverbMix: from.reverbMix + (to.reverbMix - from.reverbMix) * t
        )
    }
}

extension SlowSettings {
    /// Lo que se aplica al grafo. Siempre `AVAudioUnitTimePitch`: vinculado ⇒ pitch = 1200·log2(rate).
    var engineParameters: EngineParameters {
        EngineParameters(
            rate: Float(effectiveTempo),
            pitchCents: SlowModeMath.cents(fromSemitones: effectivePitch),
            reverbMix: Float(effectiveReverb)
        )
    }
}

enum AudioInterruption: Equatable, Sendable {
    case began
    case ended(shouldResume: Bool)
    /// Se ha desconectado la salida (p. ej. quitar los auriculares).
    case outputLost
}

/// Motor de reproducción. Protocolo para poder probar `PlayerController` sin audio real.
@MainActor
protocol PlaybackEngine: AnyObject {
    var onFinished: (() -> Void)? { get set }
    var onInterruption: ((AudioInterruption) -> Void)? { get set }
    /// Posición en segundos dentro del archivo (sin estirar).
    var currentTime: Double { get }
    func load(url: URL) throws
    func play() throws
    func pause()
    func stop()
    func seek(to seconds: Double)
    func apply(_ parameters: EngineParameters)
    /// Repite un fragmento (segundos de la pista original) sin cortes. `nil` lo quita.
    func setLoop(_ range: ClosedRange<Double>?)
}

/// Grafo: AVAudioPlayerNode → AVAudioUnitTimePitch → AVAudioUnitReverb → mainMixerNode.
/// Los nodos no cambian nunca: activar o desactivar Slow Mode solo mueve parámetros (sin cortes).
@MainActor
final class AudioEngineService: PlaybackEngine {
    var onFinished: (() -> Void)?
    var onInterruption: ((AudioInterruption) -> Void)?

    private let engine: AVAudioEngine = AVAudioEngine()
    private let playerNode: AVAudioPlayerNode = AVAudioPlayerNode()
    private let timePitch: AVAudioUnitTimePitch = AVAudioUnitTimePitch()
    private let reverb: AVAudioUnitReverb = AVAudioUnitReverb()
    private var file: AVAudioFile?
    /// Frame del archivo donde empieza el segmento programado (tras un seek).
    private var segmentStartFrame: AVAudioFramePosition = 0
    /// Frames del primer segmento programado (hasta el final del archivo o del fragmento).
    private var firstSegmentLength: AVAudioFramePosition = 0
    /// Fragmento en bucle, en frames del archivo.
    private var loopFrames: (start: AVAudioFramePosition, end: AVAudioFramePosition)?
    /// Invalida las notificaciones de fin de segmentos antiguos (seek, cambio de pista).
    private var scheduleToken: Int = 0
    private var wantsToPlay: Bool = false
    private var current: EngineParameters = .neutral
    private var rampTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    init() {
        engine.attach(playerNode)
        engine.attach(timePitch)
        engine.attach(reverb)
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 0
        reverb.bypass = true
        timePitch.rate = 1
        timePitch.pitch = 0
        engine.connect(playerNode, to: timePitch, format: nil)
        engine.connect(timePitch, to: reverb, format: nil)
        engine.connect(reverb, to: engine.mainMixerNode, format: nil)
        observeNotifications()
    }

    var currentTime: Double {
        guard let file else { return 0 }
        let sampleRate: Double = file.processingFormat.sampleRate
        var played: AVAudioFramePosition = 0
        if let nodeTime = playerNode.lastRenderTime, let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
            played = max(0, playerTime.sampleTime)
        }
        let frame: AVAudioFramePosition
        if let loop = loopFrames, played >= firstSegmentLength {
            let length: AVAudioFramePosition = max(1, loop.end - loop.start)
            frame = loop.start + (played - firstSegmentLength) % length
        } else {
            frame = segmentStartFrame + played
        }
        return min(Double(frame), Double(file.length)) / sampleRate
    }

    func setLoop(_ range: ClosedRange<Double>?) {
        guard let file else {
            loopFrames = nil
            return
        }
        let sampleRate: Double = file.processingFormat.sampleRate
        let time: Double = currentTime
        if let range {
            let start: AVAudioFramePosition = min(max(0, AVAudioFramePosition(range.lowerBound * sampleRate)), max(0, file.length - 1))
            let end: AVAudioFramePosition = min(max(start + 1, AVAudioFramePosition(range.upperBound * sampleRate)), file.length)
            loopFrames = (start, end)
        } else {
            loopFrames = nil
        }
        playerNode.stop()
        schedule(from: AVAudioFramePosition(time * sampleRate))
        if wantsToPlay { playerNode.play() }
    }

    func load(url: URL) throws {
        let newFile: AVAudioFile = try AVAudioFile(forReading: url)
        scheduleToken += 1
        playerNode.stop()
        let format: AVAudioFormat = newFile.processingFormat
        if file?.processingFormat != format {
            let wasRunning: Bool = engine.isRunning
            engine.stop()
            engine.connect(playerNode, to: timePitch, format: format)
            engine.connect(timePitch, to: reverb, format: format)
            engine.connect(reverb, to: engine.mainMixerNode, format: format)
            if wasRunning { try? engine.start() }
        }
        file = newFile
        loopFrames = nil
        schedule(from: 0)
    }

    func play() throws {
        guard file != nil else { return }
        let session: AVAudioSession = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        if !engine.isRunning {
            engine.prepare()
            try engine.start()
        }
        playerNode.play()
        wantsToPlay = true
    }

    func pause() {
        wantsToPlay = false
        playerNode.pause()
    }

    func stop() {
        wantsToPlay = false
        scheduleToken += 1
        playerNode.stop()
        file = nil
        loopFrames = nil
        segmentStartFrame = 0
    }

    func seek(to seconds: Double) {
        guard let file else { return }
        let sampleRate: Double = file.processingFormat.sampleRate
        let frame: AVAudioFramePosition = min(max(0, AVAudioFramePosition(seconds * sampleRate)), max(0, file.length - 1))
        playerNode.stop()
        schedule(from: frame)
        if wantsToPlay { playerNode.play() }
    }

    /// Aplica los parámetros con una rampa corta (~60 ms) para evitar clics.
    func apply(_ target: EngineParameters) {
        rampTask?.cancel()
        let start: EngineParameters = current
        if target.reverbMix > 0 { reverb.bypass = false }
        rampTask = Task { [weak self] in
            let steps: Int = 6
            for step in 1...steps {
                guard let self, !Task.isCancelled else { return }
                self.set(EngineParameters.interpolate(start, target, Float(step) / Float(steps)))
                if step < steps { try? await Task.sleep(for: .milliseconds(10)) }
            }
            guard let self, !Task.isCancelled else { return }
            if target.reverbMix == 0 { self.reverb.bypass = true }
        }
    }

    // MARK: - Privado

    private func set(_ parameters: EngineParameters) {
        timePitch.rate = parameters.rate
        timePitch.pitch = parameters.pitchCents
        reverb.wetDryMix = parameters.reverbMix
        current = parameters
    }

    private func schedule(from frame: AVAudioFramePosition) {
        guard let file else { return }
        scheduleToken += 1
        let token: Int = scheduleToken

        if let loop = loopFrames {
            // Primer tramo desde la posición (si está dentro del fragmento) y siempre una vuelta más en cola:
            // cada vuelta consumida programa la siguiente, así no hay hueco entre repeticiones.
            let start: AVAudioFramePosition = (frame >= loop.start && frame < loop.end) ? frame : loop.start
            segmentStartFrame = start
            firstSegmentLength = loop.end - start
            scheduleLoopSegment(from: start, to: loop.end, token: token)
            scheduleLoopSegment(from: loop.start, to: loop.end, token: token)
            return
        }

        segmentStartFrame = frame
        let remaining: AVAudioFramePosition = file.length - frame
        firstSegmentLength = max(0, remaining)
        guard remaining > 0 else { return }
        Self.scheduleSegment(on: playerNode, file: file, from: frame, count: AVAudioFrameCount(remaining), callbackType: .dataPlayedBack) { [weak self] in
            Task { @MainActor in
                self?.segmentFinished(token: token)
            }
        }
    }

    private func scheduleLoopSegment(from start: AVAudioFramePosition, to end: AVAudioFramePosition, token: Int) {
        guard let file, end > start else { return }
        Self.scheduleSegment(on: playerNode, file: file, from: start, count: AVAudioFrameCount(end - start), callbackType: .dataConsumed) { [weak self] in
            Task { @MainActor in
                self?.loopSegmentConsumed(token: token)
            }
        }
    }

    private func loopSegmentConsumed(token: Int) {
        guard token == scheduleToken, let loop = loopFrames else { return }
        scheduleLoopSegment(from: loop.start, to: loop.end, token: token)
    }

    /// Fuera del actor principal para que el callback (que llega en otro hilo) no herede `@MainActor`.
    nonisolated private static func scheduleSegment(
        on node: AVAudioPlayerNode,
        file: AVAudioFile,
        from frame: AVAudioFramePosition,
        count: AVAudioFrameCount,
        callbackType: AVAudioPlayerNodeCompletionCallbackType,
        completion: @escaping @Sendable () -> Void
    ) {
        node.scheduleSegment(file, startingFrame: frame, frameCount: count, at: nil, completionCallbackType: callbackType) { _ in
            completion()
        }
    }

    private func segmentFinished(token: Int) {
        guard token == scheduleToken, wantsToPlay else { return }
        onFinished?()
    }

    private func handle(_ event: AudioInterruption) {
        onInterruption?(event)
    }

    /// El motor se para solo si cambia la configuración de salida (p. ej. conectar AirPods): retomamos donde iba.
    private func handleConfigurationChange() {
        guard file != nil else { return }
        let time: Double = currentTime
        let resume: Bool = wantsToPlay
        playerNode.stop()
        seekWithoutPlaying(to: time)
        if resume {
            do {
                engine.prepare()
                try engine.start()
                playerNode.play()
            } catch {
                wantsToPlay = false
                onInterruption?(.outputLost)
            }
        }
    }

    private func seekWithoutPlaying(to seconds: Double) {
        guard let file else { return }
        let sampleRate: Double = file.processingFormat.sampleRate
        let frame: AVAudioFramePosition = min(max(0, AVAudioFramePosition(seconds * sampleRate)), max(0, file.length - 1))
        schedule(from: frame)
    }

    private func observeNotifications() {
        let center: NotificationCenter = NotificationCenter.default

        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let info = note.userInfo
            guard let rawType = info?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
            let event: AudioInterruption
            switch type {
            case .began:
                event = .began
            case .ended:
                let rawOptions: UInt = info?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                event = .ended(shouldResume: AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume))
            @unknown default:
                return
            }
            MainActor.assumeIsolated { self?.handle(event) }
        })

        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            guard let rawReason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: rawReason) == .oldDeviceUnavailable else { return }
            MainActor.assumeIsolated { self?.handle(.outputLost) }
        })

        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleConfigurationChange() }
        })
    }
}
