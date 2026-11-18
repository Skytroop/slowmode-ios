import Foundation
import SwiftData

/// Preset de Slow Mode guardado por el usuario. Solo ajustes y la referencia de la pista, nunca audio.
@Model
final class SlowPreset {
    @Attribute(.unique) var id: UUID
    var name: String
    var tempo: Double
    var pitch: Int
    var reverb: Int
    var linked: Bool
    /// Referencia de la pista (para emparejar con la copia local).
    var trackTitle: String
    var trackArtist: String
    var trackDuration: Int
    var creator: String
    var uses: Int
    var likes: Int
    var createdAt: Date
    var isMine: Bool

    init(
        id: UUID = UUID(),
        name: String,
        tempo: Double,
        pitch: Int,
        reverb: Int,
        linked: Bool,
        trackTitle: String,
        trackArtist: String,
        trackDuration: Int,
        creator: String = MinePresetID.creator,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.tempo = tempo
        self.pitch = pitch
        self.reverb = reverb
        self.linked = linked
        self.trackTitle = trackTitle
        self.trackArtist = trackArtist
        self.trackDuration = trackDuration
        self.creator = creator
        self.uses = 0
        self.likes = 0
        self.createdAt = createdAt
        self.isMine = true
    }
}

enum MinePresetID {
    static let prefix: String = "mine-"
    static let creator: String = "tú"
    /// Autor de los presets recibidos sin nombre de creador.
    static let receivedCreator: String = "recibido"

    static func uuid(from presetId: String) -> UUID? {
        guard presetId.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(presetId.dropFirst(prefix.count)))
    }
}

extension SlowPreset {
    /// Ajustes listos para aplicar (Slow Mode activado).
    var settings: SlowSettings {
        SlowSettings(isEnabled: true, tempo: tempo, pitch: pitch, reverb: reverb, isLinked: linked)
    }

    /// Misma forma que los presets de la comunidad, para reutilizar filas y listas.
    var communityPreset: CommunityPreset {
        CommunityPreset(
            id: MinePresetID.prefix + id.uuidString,
            name: name,
            tempo: tempo,
            pitch: pitch,
            reverb: reverb,
            linked: linked,
            track: PresetTrackReference(title: trackTitle, artist: trackArtist, duration: trackDuration),
            trackId: nil,
            artistId: nil,
            creator: PresetCreator(handle: creator, color: isMine ? "#B9C8F2" : "#F1C4DF", onColor: "#101014"),
            uses: uses,
            likes: likes,
            createdAt: createdAt
        )
    }
}
