import Foundation
import MediaPlayer
import UIKit

struct NowPlayingInfo: Equatable, Sendable {
    let title: String
    let artist: String
    let album: String
    /// Duración de la pista original (segundos).
    let duration: Double
    /// Posición en la pista original (segundos).
    let elapsed: Double
    /// Velocidad real: tempo si suena, 0 si está en pausa. El sistema estira el progreso con ella.
    let rate: Double
}

/// Acciones del centro de control y la pantalla bloqueada.
struct RemoteCommandHandlers: Sendable {
    let play: @Sendable () -> Void
    let pause: @Sendable () -> Void
    let toggle: @Sendable () -> Void
    let next: @Sendable () -> Void
    let previous: @Sendable () -> Void
    let seek: @Sendable (Double) -> Void
}

/// `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter`.
@MainActor
final class NowPlayingService {
    init() {}

    func register(_ handlers: RemoteCommandHandlers) {
        let center: MPRemoteCommandCenter = MPRemoteCommandCenter.shared()
        Self.add(center.playCommand, handlers.play)
        Self.add(center.pauseCommand, handlers.pause)
        Self.add(center.togglePlayPauseCommand, handlers.toggle)
        Self.add(center.nextTrackCommand, handlers.next)
        Self.add(center.previousTrackCommand, handlers.previous)
        Self.addSeek(center.changePlaybackPositionCommand, handlers.seek)
    }

    func update(_ info: NowPlayingInfo, artwork: UIImage?) {
        var values: [String: Any] = [
            MPMediaItemPropertyTitle: info.title,
            MPMediaItemPropertyArtist: info.artist,
            MPMediaItemPropertyPlaybackDuration: info.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: info.elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: info.rate,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
        ]
        if !info.album.isEmpty {
            values[MPMediaItemPropertyAlbumTitle] = info.album
        }
        if let artwork {
            values[MPMediaItemPropertyArtwork] = Self.makeArtwork(artwork)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = values
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // Fuera del actor principal: el sistema llama a estos bloques desde otros hilos.

    nonisolated private static func add(_ command: MPRemoteCommand, _ action: @escaping @Sendable () -> Void) {
        command.isEnabled = true
        command.addTarget { _ in
            action()
            return .success
        }
    }

    nonisolated private static func addSeek(_ command: MPChangePlaybackPositionCommand, _ action: @escaping @Sendable (Double) -> Void) {
        command.isEnabled = true
        command.addTarget { event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            action(positionEvent.positionTime)
            return .success
        }
    }

    nonisolated private static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}
