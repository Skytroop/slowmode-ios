import AVFoundation
import Foundation
import Observation
import SwiftData
import UIKit

enum ImportError: Error, Equatable, Sendable {
    case unsupportedFormat
    case outOfSpace
    case unreadable

    var message: String {
        switch self {
        case .unsupportedFormat: return "Formato no compatible"
        case .outOfSpace: return "No hay espacio suficiente en el iPhone"
        case .unreadable: return "No se pudo leer el archivo"
        }
    }
}

struct ImportFailure: Equatable, Sendable {
    let fileName: String
    let reason: ImportError
}

struct ImportOutcome: Equatable, Sendable {
    var imported: [String] = []
    /// Ya estaban en la biblioteca (mismo título, artista y duración): se omiten.
    var duplicates: [String] = []
    var failures: [ImportFailure] = []

    var summary: String {
        var parts: [String] = []
        parts.append(imported.count == 1 ? "1 pista importada" : "\(imported.count) pistas importadas")
        if !duplicates.isEmpty {
            parts.append(duplicates.count == 1 ? "1 duplicada omitida" : "\(duplicates.count) duplicadas omitidas")
        }
        if !failures.isEmpty {
            parts.append(failures.count == 1 ? "1 con error" : "\(failures.count) con error")
        }
        return parts.joined(separator: " · ")
    }

    /// Resumen + motivo de cada error + duplicados, para el aviso tras importar.
    var details: String {
        var lines: [String] = [summary]
        for failure in failures {
            lines.append("\(failure.fileName): \(failure.reason.message)")
        }
        if !duplicates.isEmpty {
            lines.append("Ya estaban en tu biblioteca: " + duplicates.joined(separator: ", "))
        }
        return lines.joined(separator: "\n")
    }
}

struct AudioMetadata: Sendable {
    let title: String?
    let artist: String?
    let album: String?
    let artworkData: Data?
    let duration: Double
}

/// Pistas importadas: copia al contenedor de la app, metadatos, portadas y SwiftData.
@MainActor
@Observable
final class LocalLibrary {
    private(set) var tracks: [Track] = []
    private(set) var isImporting: Bool = false

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored let directory: URL
    @ObservationIgnored private var artworkCache: [UUID: UIImage] = [:]

    nonisolated static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Tracks", directoryHint: .isDirectory)
    }

    init(context: ModelContext, directory: URL = LocalLibrary.defaultDirectory) {
        self.context = context
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        reload()
    }

    var catalogTracks: [CatalogTrack] { tracks.map(\.catalogTrack) }

    func reload() {
        let descriptor = FetchDescriptor<Track>(sortBy: [SortDescriptor(\Track.importedAt, order: .reverse)])
        tracks = (try? context.fetch(descriptor)) ?? []
    }

    func track(catalogId: String) -> Track? {
        guard let uuid = LocalTrackID.uuid(from: catalogId) else { return nil }
        return tracks.first { $0.id == uuid }
    }

    func fileURL(for catalogId: String) -> URL? {
        guard let track = track(catalogId: catalogId) else { return nil }
        return directory.appending(path: track.fileName)
    }

    func artwork(for catalogId: String) -> UIImage? {
        guard let track = track(catalogId: catalogId) else { return nil }
        if let cached = artworkCache[track.id] { return cached }
        guard let data = track.artworkData, let image = UIImage(data: data) else { return nil }
        artworkCache[track.id] = image
        return image
    }

    /// Copia local de la pista a la que apunta un preset (título + artista + duración ±3 s).
    func match(_ reference: PresetTrackReference) -> CatalogTrack? {
        tracks.first { track in
            SampleCatalog.sameText(track.title, reference.title)
                && SampleCatalog.sameText(track.artist, reference.artist)
                && abs(track.duration - Double(reference.duration)) <= 3
        }?.catalogTrack
    }

    func importFiles(_ urls: [URL], origin: TrackOrigin) async -> ImportOutcome {
        isImporting = true
        defer { isImporting = false }

        var outcome = ImportOutcome()
        var known: [(title: String, artist: String, duration: Double)] = tracks.map { ($0.title, $0.artist, $0.duration) }

        for url in urls {
            let originalName: String = url.lastPathComponent
            let hasAccess: Bool = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }

            let metadata: AudioMetadata
            do {
                metadata = try await Self.readMetadata(url)
            } catch let error as ImportError {
                outcome.failures.append(ImportFailure(fileName: originalName, reason: error))
                continue
            } catch {
                outcome.failures.append(ImportFailure(fileName: originalName, reason: .unreadable))
                continue
            }

            let title: String = metadata.title ?? url.deletingPathExtension().lastPathComponent
            let artist: String = metadata.artist ?? "Artista desconocido"
            let isDuplicate: Bool = known.contains { item in
                SampleCatalog.sameText(item.title, title)
                    && SampleCatalog.sameText(item.artist, artist)
                    && abs(item.duration - metadata.duration) < 1.5
            }
            if isDuplicate {
                outcome.duplicates.append(title)
                continue
            }

            let id = UUID()
            let fileExtension: String = url.pathExtension.isEmpty ? "audio" : url.pathExtension.lowercased()
            let fileName: String = "\(id.uuidString).\(fileExtension)"
            do {
                try FileManager.default.copyItem(at: url, to: directory.appending(path: fileName))
            } catch {
                outcome.failures.append(ImportFailure(fileName: originalName, reason: Self.isOutOfSpace(error) ? .outOfSpace : .unreadable))
                continue
            }

            let track = Track(
                id: id,
                title: title,
                artist: artist,
                album: metadata.album ?? "",
                duration: metadata.duration,
                fileName: fileName,
                origin: origin,
                artworkData: metadata.artworkData
            )
            context.insert(track)
            known.append((title, artist, metadata.duration))
            outcome.imported.append(title)
        }

        try? context.save()
        reload()
        return outcome
    }

    func delete(_ track: Track) {
        try? FileManager.default.removeItem(at: directory.appending(path: track.fileName))
        artworkCache[track.id] = nil
        context.delete(track)
        try? context.save()
        reload()
    }

    // MARK: - Metadatos (fuera del actor principal)

    /// Comprueba que AVFoundation puede leer el audio y saca título, artista, álbum, portada y duración.
    nonisolated static func readMetadata(_ url: URL) async throws -> AudioMetadata {
        let duration: Double
        do {
            let file: AVAudioFile = try AVAudioFile(forReading: url)
            duration = Double(file.length) / file.processingFormat.sampleRate
        } catch {
            throw ImportError.unsupportedFormat
        }
        guard duration > 0 else { throw ImportError.unsupportedFormat }

        var title: String?
        var artist: String?
        var album: String?
        var artwork: Data?
        let asset = AVURLAsset(url: url)
        if let items = try? await asset.load(.commonMetadata) {
            for item in items {
                guard let key: AVMetadataKey = item.commonKey else { continue }
                if key == .commonKeyTitle {
                    title = try? await item.load(.stringValue)
                } else if key == .commonKeyArtist {
                    artist = try? await item.load(.stringValue)
                } else if key == .commonKeyAlbumName {
                    album = try? await item.load(.stringValue)
                } else if key == .commonKeyArtwork {
                    artwork = try? await item.load(.dataValue)
                }
            }
        }
        return AudioMetadata(
            title: nonEmpty(title),
            artist: nonEmpty(artist),
            album: nonEmpty(album),
            artworkData: artwork,
            duration: duration
        )
    }

    nonisolated private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    nonisolated private static func isOutOfSpace(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteOutOfSpaceError
    }
}
