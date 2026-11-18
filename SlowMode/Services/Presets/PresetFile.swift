import CoreTransferable
import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// Archivo `.slowpreset` (declarado en Info.plist mediante `project.yml`).
    static let slowPreset: UTType = UTType(exportedAs: "com.slowmode.preset", conformingTo: .json)
}

enum PresetFileError: Error, Equatable, Sendable {
    case invalid
    case newerVersion

    var message: String {
        switch self {
        case .invalid: return "El archivo no es un preset de Slow Mode válido."
        case .newerVersion: return "Este preset es de una versión más nueva de Slow Mode. Actualiza la app para abrirlo."
        }
    }
}

/// Lo que viaja al compartir un preset: solo ajustes y la referencia de la pista. Nunca audio.
struct PresetFile: Codable, Equatable, Sendable {
    static let formatName: String = "slowmode.preset"
    static let currentVersion: Int = 1
    static let fileExtension: String = "slowpreset"

    var format: String
    var version: Int
    var name: String
    var tempo: Double
    var pitch: Int
    var reverb: Int
    var linked: Bool
    var track: PresetTrackReference
    /// Quién lo creó (`nil` si lo comparte su autor, que aún no tiene perfil).
    var creator: String?

    init(name: String, tempo: Double, pitch: Int, reverb: Int, linked: Bool, track: PresetTrackReference, creator: String?) {
        self.format = Self.formatName
        self.version = Self.currentVersion
        self.name = name
        self.tempo = tempo
        self.pitch = pitch
        self.reverb = reverb
        self.linked = linked
        self.track = track
        self.creator = creator
    }

    /// Ajustes actuales de Slow Mode para una pista.
    init(name: String, settings: SlowSettings, track: CatalogTrack) {
        self.init(
            name: name,
            tempo: settings.tempo,
            pitch: settings.displayedPitch,
            reverb: settings.reverb,
            linked: settings.isLinked,
            track: PresetTrackReference(title: track.title, artist: track.artist, duration: track.duration),
            creator: nil
        )
    }

    /// Cualquier preset de la lista (tuyo, recibido o de la comunidad).
    init(preset: CommunityPreset) {
        let creator: String? = preset.creator.handle == MinePresetID.creator ? nil : preset.creator.handle
        self.init(
            name: preset.name,
            tempo: preset.tempo,
            pitch: preset.pitch,
            reverb: preset.reverb,
            linked: preset.linked,
            track: preset.track,
            creator: creator
        )
    }

    var settings: SlowSettings {
        SlowSettings(isEnabled: true, tempo: tempo, pitch: pitch, reverb: reverb, isLinked: linked)
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Lee y valida un archivo. Ajusta los valores fuera de rango.
    static func decode(_ data: Data) throws -> PresetFile {
        guard var file = try? JSONDecoder().decode(PresetFile.self, from: data), file.format == formatName else {
            throw PresetFileError.invalid
        }
        guard file.version <= currentVersion else { throw PresetFileError.newerVersion }
        let name: String = file.name.trimmingCharacters(in: .whitespacesAndNewlines)
        file.name = name.isEmpty ? "Preset compartido" : String(name.prefix(60))
        file.tempo = SlowModeMath.clampTempo(file.tempo)
        file.pitch = SlowModeMath.clampPitch(file.pitch)
        file.reverb = SlowModeMath.clampReverb(file.reverb)
        file.track = PresetTrackReference(
            title: String(file.track.title.prefix(200)),
            artist: String(file.track.artist.prefix(200)),
            duration: max(0, file.track.duration)
        )
        if let creator = file.creator?.trimmingCharacters(in: .whitespacesAndNewlines) {
            file.creator = creator.isEmpty ? nil : String(creator.prefix(40))
        }
        return file
    }

    /// "Ralentizado 0.85× · Glass Hours.slowpreset", sin caracteres problemáticos.
    var fileName: String {
        let raw: String = "\(name) · \(track.title)"
        let forbidden: CharacterSet = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.newlines).union(.controlCharacters)
        let cleaned: String = raw.components(separatedBy: forbidden).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        let base: String = cleaned.isEmpty ? "Preset" : String(cleaned.prefix(80))
        return "\(base).\(Self.fileExtension)"
    }

    /// Escribe el archivo en una carpeta temporal propia y devuelve su URL.
    func writeTemporaryFile() throws -> URL {
        let folder: URL = FileManager.default.temporaryDirectory
            .appending(path: "SharedPresets", directoryHint: .isDirectory)
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url: URL = folder.appending(path: fileName)
        try encoded().write(to: url, options: .atomic)
        return url
    }

    /// Texto que acompaña al archivo al compartir.
    var shareMessage: String {
        let summary: String = SlowModeFormat.summary(tempo: tempo, pitch: pitch, reverb: reverb) ?? "Original"
        return "Preset de Slow Mode «\(name)» (\(summary)) para «\(track.title)» de \(track.artist). Ábrelo con Slow Mode; se aplica a tu propia copia de la canción."
    }
}

/// Para `ShareLink`: genera el archivo `.slowpreset` al compartir.
struct PresetShareItem: Transferable {
    let file: PresetFile

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .slowPreset) { item in
            SentTransferredFile(try item.file.writeTemporaryFile())
        }
    }
}
