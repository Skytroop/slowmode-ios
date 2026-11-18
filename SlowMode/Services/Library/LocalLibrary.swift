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
    /// Ya estaban en la biblioteca (mismo título, artista y duración).
    var duplicates: [String] = []
    /// Archivos de los duplicados, por si el usuario decide importarlos igualmente.
    var duplicateURLs: [URL] = []
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
    let genre: String?
    let artworkData: Data?
    let duration: Double
}

/// Tu música: pistas importadas, me gusta, playlists, escuchas y estadísticas. Todo en SwiftData, en el iPhone.
@MainActor
@Observable
final class LocalLibrary {
    private(set) var tracks: [Track] = []
    private(set) var playlists: [Playlist] = []
    /// Cachés derivadas (se recalculan al cambiar pistas o escuchas).
    private(set) var catalogTracks: [CatalogTrack] = []
    private(set) var artists: [CatalogArtist] = []
    private(set) var homeStats: HomeStats = SampleCatalog.empty.home
    private(set) var isImporting: Bool = false

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored let directory: URL
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var artworkCache: [UUID: UIImage] = [:]
    @ObservationIgnored private var tracker: ListeningTracker = ListeningTracker()
    @ObservationIgnored private var currentSessionID: UUID?
    @ObservationIgnored private var currentEvent: PlayEvent?
    @ObservationIgnored private var unsavedSeconds: Double = 0

    nonisolated static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Tracks", directoryHint: .isDirectory)
    }

    init(
        context: ModelContext,
        directory: URL = LocalLibrary.defaultDirectory,
        now: @escaping () -> Date = { Date.now },
        backfillsGenres: Bool = true
    ) {
        self.context = context
        self.directory = directory
        self.now = now
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        reload()
        if backfillsGenres {
            Task { [weak self] in await self?.backfillGenres() }
        }
    }

    // MARK: - Lectura

    func reload() {
        let trackDescriptor = FetchDescriptor<Track>(sortBy: [SortDescriptor(\Track.importedAt, order: .reverse)])
        tracks = (try? context.fetch(trackDescriptor)) ?? []
        let playlistDescriptor = FetchDescriptor<Playlist>(sortBy: [SortDescriptor(\Playlist.createdAt)])
        playlists = (try? context.fetch(playlistDescriptor)) ?? []
        refreshDerived()
    }

    private func refreshDerived() {
        catalogTracks = tracks.map(\.catalogTrack)
        artists = ListeningStats.artists(from: tracks.map { TrackSnapshot(artist: $0.artist, genre: $0.genre, plays: $0.plays) })
        let events: [PlayEvent] = (try? context.fetch(FetchDescriptor<PlayEvent>())) ?? []
        let snapshots: [PlaySnapshot] = events.map { PlaySnapshot(date: $0.date, seconds: $0.seconds, genre: $0.genre) }
        homeStats = HomeStats(
            songsPlayed: events.count,
            streakDays: ListeningStats.streak(snapshots, now: now()),
            trackCount: tracks.count,
            topGenres: ListeningStats.topGenres(snapshots),
            discover: ListeningStats.discover(artists)
        )
    }

    /// Tu música con la forma del catálogo, para reutilizar Inicio, Buscar, Artista y Biblioteca.
    /// Las mezclas, oyentes y presets de la comunidad siguen siendo de ejemplo hasta la Fase 5.
    func userCatalog(community: SampleCatalog, myPresets: [CommunityPreset]) -> SampleCatalog {
        SampleCatalog(
            artists: artists,
            tracks: catalogTracks,
            presets: myPresets + community.presets,
            mixes: community.mixes,
            listeners: community.listeners,
            home: homeStats
        )
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

    // MARK: - Me gusta

    func isLiked(catalogId: String) -> Bool {
        track(catalogId: catalogId)?.isLiked ?? false
    }

    func toggleLike(catalogId: String) {
        guard let track = track(catalogId: catalogId) else { return }
        track.isLiked.toggle()
        try? context.save()
    }

    var likedTracks: [CatalogTrack] {
        tracks.filter(\.isLiked).map(\.catalogTrack)
    }

    // MARK: - Playlists

    func playlist(id: UUID) -> Playlist? {
        playlists.first { $0.id == id }
    }

    /// Crea una playlist. Devuelve `nil` si el nombre está vacío.
    @discardableResult
    func createPlaylist(named name: String) -> Playlist? {
        let trimmed: String = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let playlist = Playlist(name: trimmed, createdAt: now())
        context.insert(playlist)
        try? context.save()
        reload()
        return playlist
    }

    /// Añade una pista (sin duplicados). Devuelve `false` si ya estaba o la pista no es tuya.
    @discardableResult
    func add(trackCatalogId: String, to playlist: Playlist) -> Bool {
        guard let uuid = LocalTrackID.uuid(from: trackCatalogId), !playlist.trackIDs.contains(uuid) else { return false }
        playlist.trackIDs.append(uuid)
        try? context.save()
        return true
    }

    func remove(trackCatalogId: String, from playlist: Playlist) {
        guard let uuid = LocalTrackID.uuid(from: trackCatalogId) else { return }
        playlist.trackIDs.removeAll { $0 == uuid }
        try? context.save()
    }

    func delete(_ playlist: Playlist) {
        context.delete(playlist)
        try? context.save()
        reload()
    }

    /// Pistas de la playlist en su orden (omite las que ya no existen).
    func tracks(in playlist: Playlist) -> [CatalogTrack] {
        playlist.trackIDs.compactMap { id in tracks.first { $0.id == id }?.catalogTrack }
    }

    // MARK: - Género

    /// Pone el mismo género a todas las pistas de un artista.
    func setGenre(_ genre: String, forArtistId artistId: String) {
        let trimmed: String = genre.trimmingCharacters(in: .whitespacesAndNewlines)
        for track in tracks where LocalTrackID.artistId(for: track.artist) == artistId {
            track.genre = trimmed
            track.genreChecked = true
        }
        try? context.save()
        refreshDerived()
    }

    /// Lee el género del archivo en las pistas importadas antes de que la app lo guardara.
    func backfillGenres() async {
        let pending: [Track] = tracks.filter { !$0.genreChecked }
        guard !pending.isEmpty else { return }
        for track in pending {
            let url: URL = directory.appending(path: track.fileName)
            let genre: String? = await Self.readGenre(url)
            if track.genre.isEmpty, let genre { track.genre = genre }
            track.genreChecked = true
        }
        try? context.save()
        refreshDerived()
    }

    // MARK: - Escuchas

    /// Recibe los ticks del reproductor y apunta la escucha cuando cuenta.
    func handle(_ tick: ListeningTick) {
        guard let track = track(catalogId: tick.trackID) else { return }
        if tick.sessionID != currentSessionID {
            currentSessionID = tick.sessionID
            currentEvent = nil
            unsavedSeconds = 0
        }
        switch tracker.record(tick) {
        case .none:
            break
        case .counted(let seconds):
            let date: Date = now()
            let event = PlayEvent(
                trackID: track.id,
                date: date,
                seconds: seconds,
                tempo: tick.tempo,
                artist: track.artist,
                genre: track.genre
            )
            context.insert(event)
            track.plays += 1
            track.lastPlayedAt = date
            currentEvent = event
            try? context.save()
            refreshDerived()
        case .extended(let seconds):
            guard let currentEvent else { return }
            currentEvent.seconds += seconds
            unsavedSeconds += seconds
            if unsavedSeconds >= 10 {
                unsavedSeconds = 0
                try? context.save()
            }
        }
    }

    // MARK: - Importar

    /// Importa archivos. Los duplicados se omiten (y se devuelven sus URLs) salvo que `allowDuplicates` sea `true`.
    func importFiles(_ urls: [URL], origin: TrackOrigin, allowDuplicates: Bool = false) async -> ImportOutcome {
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
            if isDuplicate && !allowDuplicates {
                outcome.duplicates.append(title)
                outcome.duplicateURLs.append(url)
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
                artworkData: metadata.artworkData,
                genre: metadata.genre ?? "",
                importedAt: now()
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
        for playlist in playlists {
            playlist.trackIDs.removeAll { $0 == track.id }
        }
        context.delete(track)
        try? context.save()
        reload()
    }

    // MARK: - Metadatos (fuera del actor principal)

    /// Comprueba que AVFoundation puede leer el audio y saca título, artista, álbum, género, portada y duración.
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
        let genre: String? = await genre(from: asset)
        return AudioMetadata(
            title: nonEmpty(title),
            artist: nonEmpty(artist),
            album: nonEmpty(album),
            genre: genre,
            artworkData: artwork,
            duration: duration
        )
    }

    nonisolated static func readGenre(_ url: URL) async -> String? {
        await genre(from: AVURLAsset(url: url))
    }

    /// Género de las etiquetas ID3, iTunes o QuickTime.
    nonisolated private static func genre(from asset: AVURLAsset) async -> String? {
        guard let items = try? await asset.load(.metadata) else { return nil }
        let textIdentifiers: [AVMetadataIdentifier] = [
            .id3MetadataContentType,
            .iTunesMetadataUserGenre,
            .quickTimeMetadataGenre,
        ]
        for item in items {
            guard let identifier = item.identifier else { continue }
            if textIdentifiers.contains(identifier) {
                if let text = try? await item.load(.stringValue), let genre = GenreName.normalize(text) {
                    return genre
                }
            } else if identifier == .iTunesMetadataPredefinedGenre {
                if let number = try? await item.load(.numberValue), let genre = GenreName.id3Name(number.intValue - 1) {
                    return genre
                }
            }
        }
        return nil
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
