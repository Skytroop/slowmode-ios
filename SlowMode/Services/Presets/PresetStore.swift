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
        guard let preset = preset(presetId: presetId) else { return }
        delete(preset)
    }

    func preset(presetId: String) -> SlowPreset? {
        guard let uuid = MinePresetID.uuid(from: presetId) else { return nil }
        return presets.first { $0.id == uuid }
    }

    /// Cambia el nombre. Devuelve `false` si el nombre está vacío.
    @discardableResult
    func rename(_ preset: SlowPreset, to name: String) -> Bool {
        let trimmed: String = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        preset.name = String(trimmed.prefix(60))
        try? context.save()
        reload()
        return true
    }

    @discardableResult
    func rename(presetId: String, to name: String) -> Bool {
        guard let preset = preset(presetId: presetId) else { return false }
        return rename(preset, to: name)
    }

    /// Guarda un preset recibido (archivo `.slowpreset`). Si ya lo tenías igual, devuelve el existente.
    @discardableResult
    func saveReceived(_ file: PresetFile) -> SlowPreset {
        if let existing = presets.first(where: { preset in
            preset.name == file.name
                && abs(preset.tempo - file.tempo) < 0.001
                && preset.pitch == file.pitch
                && preset.reverb == file.reverb
                && preset.linked == file.linked
                && SampleCatalog.sameText(preset.trackTitle, file.track.title)
                && SampleCatalog.sameText(preset.trackArtist, file.track.artist)
        }) {
            return existing
        }
        let preset = SlowPreset(
            name: file.name,
            tempo: file.tempo,
            pitch: file.pitch,
            reverb: file.reverb,
            linked: file.linked,
            trackTitle: file.track.title,
            trackArtist: file.track.artist,
            trackDuration: file.track.duration,
            creator: file.creator ?? MinePresetID.receivedCreator
        )
        preset.isMine = false
        context.insert(preset)
        try? context.save()
        reload()
        return preset
    }

    /// Nombre propuesto: el del preset rápido si coincide; si no, según la velocidad.
    static func suggestedName(for settings: SlowSettings) -> String {
        if let quick = QuickPreset.all.dropFirst().first(where: { settings.matches($0) }) {
            return "\(quick.name) \(SlowModeFormat.tempo(quick.tempo))"
        }
        return "\(SlowModeFormat.modeName(tempo: settings.tempo)) \(SlowModeFormat.tempo(settings.tempo))"
    }
}
