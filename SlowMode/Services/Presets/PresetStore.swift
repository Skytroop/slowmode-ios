import Foundation
import Observation
import SwiftData

/// Presets propios guardados en SwiftData.
@MainActor
@Observable
final class PresetStore {
    private(set) var presets: [SlowPreset] = []
    @ObservationIgnored private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        reload()
    }

    func reload() {
        let descriptor = FetchDescriptor<SlowPreset>(sortBy: [SortDescriptor(\SlowPreset.createdAt, order: .reverse)])
        presets = (try? context.fetch(descriptor)) ?? []
    }

    /// Todos los presets propios con la forma de los de la comunidad.
    var communityPresets: [CommunityPreset] { presets.map(\.communityPreset) }

    /// Guarda los ajustes actuales para una pista. Devuelve `nil` si el nombre está vacío.
    @discardableResult
    func save(name: String, settings: SlowSettings, for track: CatalogTrack) -> SlowPreset? {
        let trimmed: String = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let preset = SlowPreset(
            name: trimmed,
            tempo: settings.tempo,
            pitch: settings.displayedPitch,
            reverb: settings.reverb,
            linked: settings.isLinked,
            trackTitle: track.title,
            trackArtist: track.artist,
            trackDuration: track.duration
        )
        context.insert(preset)
        try? context.save()
        reload()
        return preset
    }

    /// Presets propios de una pista (título + artista + duración ±3 s).
    func presets(for track: CatalogTrack) -> [SlowPreset] {
        presets.filter { preset in
            SampleCatalog.sameText(preset.trackTitle, track.title)
                && SampleCatalog.sameText(preset.trackArtist, track.artist)
                && abs(preset.trackDuration - track.duration) <= 3
        }
    }

    func delete(_ preset: SlowPreset) {
        context.delete(preset)
        try? context.save()
        reload()
    }

    /// Borra a partir del id con forma de comunidad (`mine-<uuid>`).
    func delete(presetId: String) {
        guard let uuid = MinePresetID.uuid(from: presetId),
              let preset = presets.first(where: { $0.id == uuid }) else { return }
        delete(preset)
    }

    /// Nombre propuesto: el del preset rápido si coincide; si no, según la velocidad.
    static func suggestedName(for settings: SlowSettings) -> String {
        if let quick = QuickPreset.all.dropFirst().first(where: { settings.matches($0) }) {
            return "\(quick.name) \(SlowModeFormat.tempo(quick.tempo))"
        }
        return "\(SlowModeFormat.modeName(tempo: settings.tempo)) \(SlowModeFormat.tempo(settings.tempo))"
    }
}
