import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum LibraryTile: String, CaseIterable, Identifiable {
    case liked, playlists, albums, artists

    var id: String { rawValue }

    var title: String {
        switch self {
        case .liked: return "Canciones que te gustan"
        case .playlists: return "Playlists"
        case .albums: return "Álbumes"
        case .artists: return "Artistas"
        }
    }

    var symbol: String {
        switch self {
        case .liked: return "heart.fill"
        case .playlists: return "music.note.list"
        case .albums: return "square.stack"
        case .artists: return "music.mic"
        }
    }
}

struct LibraryView: View {
    @Environment(CatalogStore.self) private var store: CatalogStore
    @Environment(LibraryStore.self) private var library: LibraryStore
    @Environment(LocalLibrary.self) private var localLibrary: LocalLibrary
    @Environment(PresetStore.self) private var presetStore: PresetStore
    @Environment(PlayerController.self) private var player: PlayerController
    @Environment(AppNavigation.self) private var navigation: AppNavigation
    @State private var tile: LibraryTile = .liked
    @State private var isNamingPlaylist: Bool = false
    @State private var newPlaylistName: String = ""
    @State private var pendingOrigin: TrackOrigin?
    @State private var importOrigin: TrackOrigin = .localFile
    @State private var importResult: ImportOutcome?
    @State private var pendingDuplicates: ImportOutcome?

    var body: some View {
        @Bindable var navigation = navigation
        let catalog: SampleCatalog = localLibrary.userCatalog(community: store.catalog, myPresets: presetStore.communityPresets)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Button {
                    navigation.isImportPresented = true
                } label: {
                    Label("Importar o subir audio", systemImage: "square.and.arrow.down")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass)

                yourMusic(catalog)

                tiles(catalog)
                tileContent(catalog)

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Presets de Slow Mode guardados")
                    PresetListSection(
                        presets: presetStore.communityPresets + store.catalog.presets.filter { library.isLiked(presetId: $0.id) },
                        showsArtist: true,
                        showsControls: false,
                        emptyTitle: "Sin presets guardados",
                        emptyMessage: "Guarda tu versión desde Reproduciendo o dale a me gusta a un preset de la comunidad.",
                        onDelete: { preset in presetStore.delete(presetId: preset.id) },
                        onRename: { preset, name in _ = presetStore.rename(presetId: preset.id, to: name) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(AmbientBackground())
        .navigationTitle("Biblioteca")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newPlaylistName = ""
                    isNamingPlaylist = true
                } label: {
                    Label("Crear playlist", systemImage: "plus")
                }
            }
        }
        .alert("Nueva playlist", isPresented: $isNamingPlaylist) {
            TextField("Nombre", text: $newPlaylistName)
            Button("Crear") {
                if localLibrary.createPlaylist(named: newPlaylistName) != nil {
                    tile = .playlists
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .sheet(isPresented: $navigation.isImportPresented, onDismiss: openPickerIfChosen) {
            ImportSheet { origin in pendingOrigin = origin }
        }
        .overlay {
            if localLibrary.isImporting {
                ProgressView("Importando…")
                    .padding(24)
                    .glassEffect(.regular, in: .rect(cornerRadius: Radius.list))
            }
        }
        .alert(
            "Canciones repetidas",
            isPresented: Binding(get: { pendingDuplicates != nil }, set: { if !$0 { pendingDuplicates = nil } }),
            presenting: pendingDuplicates
        ) { outcome in
            Button("Importar igualmente") { resolveDuplicates(outcome, importAnyway: true) }
            Button("Omitir", role: .cancel) { resolveDuplicates(outcome, importAnyway: false) }
        } message: { outcome in
            Text("Ya tienes en tu biblioteca: \(outcome.duplicates.joined(separator: ", ")). ¿Quieres importarlas otra vez?")
        }
        .alert(
            "Importación",
            isPresented: Binding(get: { importResult != nil }, set: { if !$0 { importResult = nil } }),
            presenting: importResult
        ) { _ in
            Button("Aceptar", role: .cancel) {}
        } message: { outcome in
            Text(outcome.details)
        }
    }

    // MARK: - Importar

    /// Al cerrarse la hoja de importar, abre el selector si se eligió una opción.
    private func openPickerIfChosen() {
        guard let origin = pendingOrigin else { return }
        pendingOrigin = nil
        importOrigin = origin
        AudioFilePicker.shared.present { urls in runImport(urls) }
    }

    private func runImport(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let origin: TrackOrigin = importOrigin
        Task {
            let outcome: ImportOutcome = await localLibrary.importFiles(urls, origin: origin)
            // Las copias temporales del selector ya no hacen falta (salvo las repetidas, hasta que decidas).
            let kept: Set<URL> = Set(outcome.duplicateURLs)
            for url in urls where !kept.contains(url) {
                try? FileManager.default.removeItem(at: url)
            }
            if outcome.duplicateURLs.isEmpty {
                importResult = outcome
            } else {
                pendingDuplicates = outcome
            }
        }
    }

    private func resolveDuplicates(_ outcome: ImportOutcome, importAnyway: Bool) {
        let origin: TrackOrigin = importOrigin
        Task {
            var result: ImportOutcome = outcome
            if importAnyway {
                let extra: ImportOutcome = await localLibrary.importFiles(outcome.duplicateURLs, origin: origin, allowDuplicates: true)
                result.imported += extra.imported
                result.failures += extra.failures
                result.duplicates = []
            }
            for url in outcome.duplicateURLs {
                try? FileManager.default.removeItem(at: url)
            }
            result.duplicateURLs = []
            // Deja que se cierre el primer aviso antes de mostrar el resultado.
            try? await Task.sleep(for: .milliseconds(450))
            importResult = result
        }
    }

    // MARK: - Tu música

    /// Todas tus pistas importadas. Mantén pulsada una para más opciones.
    @ViewBuilder
    private func yourMusic(_ catalog: SampleCatalog) -> some View {
        let tracks: [CatalogTrack] = catalog.tracks
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Tu música") {
                if !tracks.isEmpty {
                    Text("\(tracks.count)")
                        .textStyle(.caption)
                        .monospacedDigit()
                }
            }
            if tracks.isEmpty {
                ContentUnavailableView {
                    Label("Importa tu música para empezar", systemImage: "music.note")
                } description: {
                    Text("MP3, AAC, FLAC, WAV o AIFF desde Archivos o iCloud Drive.")
                } actions: {
                    Button("Importar") { navigation.isImportPresented = true }
                        .buttonStyle(.glassProminent)
                }
            } else {
                trackList(tracks, source: "Tu música", catalog: catalog)
            }
        }
    }

    private func trackList(_ tracks: [CatalogTrack], source: String, catalog: SampleCatalog) -> some View {
        SurfaceList(items: tracks) { track in
            Button {
                player.play(track, in: tracks, from: source)
            } label: {
                TrackRow(
                    title: track.title,
                    subtitle: track.artist,
                    artwork: ArtworkColors.forArtist(track.artistId, in: catalog),
                    origin: track.origin,
                    trailing: SlowModeFormat.duration(Double(track.duration)),
                    isCurrent: player.currentTrack?.id == track.id,
                    image: localLibrary.artwork(for: track.id)
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    localLibrary.toggleLike(catalogId: track.id)
                } label: {
                    if localLibrary.isLiked(catalogId: track.id) {
                        Label("Quitar me gusta", systemImage: "heart.slash")
                    } else {
                        Label("Me gusta", systemImage: "heart")
                    }
                }
                if !localLibrary.playlists.isEmpty {
                    Menu {
                        ForEach(localLibrary.playlists) { playlist in
                            Button(playlist.name) {
                                localLibrary.add(trackCatalogId: track.id, to: playlist)
                            }
                        }
                    } label: {
                        Label("Añadir a playlist", systemImage: "text.badge.plus")
                    }
                }
                Button(role: .destructive) {
                    delete(track)
                } label: {
                    Label("Eliminar de la biblioteca", systemImage: "trash")
                }
            }
        }
    }

    private func delete(_ track: CatalogTrack) {
        if player.currentTrack?.id == track.id && player.isPlaying {
            player.pause()
        }
        if let stored = localLibrary.track(catalogId: track.id) {
            localLibrary.delete(stored)
        }
    }

    // MARK: - Tiles

    private func count(for tile: LibraryTile, _ catalog: SampleCatalog) -> Int {
        switch tile {
        case .liked: return localLibrary.likedTracks.count
        case .playlists: return localLibrary.playlists.count
        case .albums: return catalog.albums.count
        case .artists: return catalog.artists.count
        }
    }

    private func tiles(_ catalog: SampleCatalog) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(LibraryTile.allCases) { option in
                LibraryTileButton(
                    tile: option,
                    count: count(for: option, catalog),
                    isSelected: tile == option
                ) {
                    tile = option
                }
            }
        }
    }

    @ViewBuilder
    private func tileContent(_ catalog: SampleCatalog) -> some View {
        switch tile {
        case .liked:
            let liked: [CatalogTrack] = localLibrary.likedTracks
            if liked.isEmpty {
                ContentUnavailableView("Aún no te gusta ninguna canción", systemImage: "heart", description: Text("Toca el corazón en Reproduciendo para guardarla aquí."))
            } else {
                trackList(liked, source: "Canciones que te gustan", catalog: catalog)
            }
        case .playlists:
            if localLibrary.playlists.isEmpty {
                ContentUnavailableView("Sin playlists", systemImage: "music.note.list", description: Text("Crea una con el botón +."))
            } else {
                SurfaceList(items: localLibrary.playlists) { playlist in
                    NavigationLink(value: AppRoute.playlist(playlist.id)) {
                        EntityRow(
                            title: playlist.name,
                            subtitle: playlist.trackIDs.count == 1 ? "1 canción" : "\(playlist.trackIDs.count) canciones",
                            leading: .gradient(AnyShapeStyle(Palette.pinkGradient), symbol: "music.note.list"),
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        case .albums:
            if catalog.albums.isEmpty {
                ContentUnavailableView("Sin álbumes", systemImage: "square.stack", description: Text("Aparecerán cuando importes música."))
            } else {
                SurfaceList(items: catalog.albums) { album in
                    NavigationLink(value: AppRoute.artist(album.artistId)) {
                        EntityRow(
                            title: album.title.isEmpty ? "Sin álbum" : album.title,
                            subtitle: "\(album.artist) · \(album.trackCount) " + (album.trackCount == 1 ? "canción" : "canciones"),
                            leading: .artwork(ArtworkColors.forArtist(album.artistId, in: catalog)),
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        case .artists:
            if catalog.artists.isEmpty {
                ContentUnavailableView("Sin artistas", systemImage: "music.mic", description: Text("Aparecerán cuando importes música."))
            } else {
                SurfaceList(items: catalog.artists) { artist in
                    NavigationLink(value: AppRoute.artist(artist.id)) {
                        EntityRow(
                            title: artist.name,
                            subtitle: "\(artist.genre) · \(artist.plays) reproducciones",
                            leading: .avatar(initials: artist.initials, colors: ArtworkColors(hexBackground: artist.color, hexForeground: artist.onColor)),
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct LibraryTileButton: View {
    let tile: LibraryTile
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme: Theme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: tile.symbol)
                    .font(.title3.weight(.medium))
                    .accessibilityHidden(true)
                Spacer(minLength: 4)
                Text(tile.title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Text("\(count)")
                    .font(.caption)
                    .monospacedDigit()
                    .opacity(0.75)
            }
            .foregroundStyle(isSelected ? Palette.ink : Palette.textPrimary)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .background(
                isSelected ? AnyShapeStyle(Palette.periwinkleGradient) : AnyShapeStyle(theme.surface),
                in: .rect(cornerRadius: Radius.list)
            )
            .contentShape(.rect(cornerRadius: Radius.list))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tile.title), \(count)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Hoja "Importar o subir audio": solo elige el tipo. El selector de Archivos se abre desde
/// Biblioteca al cerrarse esta hoja (presentarlo dentro de otra hoja impedía que se cerrara).
struct ImportSheet: View {
    let onChoose: (TrackOrigin) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    option(
                        title: "Importar desde Archivos",
                        detail: "MP3, AAC, FLAC, WAV o AIFF de Archivos o iCloud Drive",
                        symbol: "folder",
                        origin: .localFile
                    )
                    option(
                        title: "Subir un original",
                        detail: "Grabaciones y mezclas propias que se pueden compartir",
                        symbol: "waveform.badge.plus",
                        origin: .originalUpload
                    )
                } footer: {
                    Text("Las pistas se copian a la app y se quedan en este iPhone. Puedes elegir varias a la vez.")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Importar o subir audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func option(title: String, detail: String, symbol: String, origin: TrackOrigin) -> some View {
        Button {
            onChoose(origin)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(Palette.periwinkle)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).textStyle(.body)
                    Text(detail).textStyle(.caption)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 52)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Selector de documentos de UIKit en modo copia (el sistema entrega copias locales, también de iCloud Drive).
/// Se presenta directamente con UIKit sobre la pantalla visible: envolverlo en una hoja de SwiftUI hacía que,
/// al cerrarse solo tras elegir, SwiftUI creyera que seguía abierta y bloqueara otras presentaciones
/// (por ejemplo, abrir Reproduciendo).
@MainActor
final class AudioFilePicker: NSObject, UIDocumentPickerDelegate {
    static let shared: AudioFilePicker = AudioFilePicker()

    private var completion: (([URL]) -> Void)?

    /// Abre el selector. `completion` recibe los archivos elegidos (vacío si se cancela).
    func present(completion: @escaping ([URL]) -> Void) {
        guard let presenter = Self.topViewController() else {
            completion([])
            return
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.shouldShowFileExtensions = true
        picker.delegate = self
        self.completion = completion
        presenter.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        finish(urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finish([])
    }

    private func finish(_ urls: [URL]) {
        let callback = completion
        completion = nil
        callback?(urls)
    }

    private static func topViewController() -> UIViewController? {
        let scenes: [UIWindowScene] = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows: [UIWindow] = scenes.flatMap(\.windows)
        let window: UIWindow? = windows.first(where: \.isKeyWindow) ?? windows.first
        var top: UIViewController? = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
