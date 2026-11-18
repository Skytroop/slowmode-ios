import SwiftUI
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
    @Environment(PlayerController.self) private var player: PlayerController
    @Environment(AppNavigation.self) private var navigation: AppNavigation
    @State private var tile: LibraryTile = .liked
    @State private var isNamingPlaylist: Bool = false
    @State private var newPlaylistName: String = ""

    var body: some View {
        @Bindable var navigation = navigation
        let catalog: SampleCatalog = store.catalog

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
                        presets: catalog.presets.filter { library.isLiked(presetId: $0.id) },
                        showsArtist: true,
                        showsControls: false,
                        emptyTitle: "Sin presets guardados",
                        emptyMessage: "Dale a me gusta a un preset de la comunidad para guardarlo aquí."
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
                if library.createPlaylist(named: newPlaylistName) != nil {
                    tile = .playlists
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .sheet(isPresented: $navigation.isImportPresented) {
            ImportSheet()
        }
    }

    /// Pistas importadas (suenan de verdad). Mantén pulsada una para eliminarla.
    @ViewBuilder
    private func yourMusic(_ catalog: SampleCatalog) -> some View {
        let tracks: [CatalogTrack] = localLibrary.catalogTracks
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
                SurfaceList(items: tracks) { track in
                    Button {
                        player.play(track, in: tracks, from: "Tu música")
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
                        Button(role: .destructive) {
                            delete(track)
                        } label: {
                            Label("Eliminar de la biblioteca", systemImage: "trash")
                        }
                    }
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

    private func count(for tile: LibraryTile, _ catalog: SampleCatalog) -> Int {
        switch tile {
        case .liked: return catalog.tracks.filter { library.isLiked(trackId: $0.id) }.count
        case .playlists: return library.playlists.count
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
            let liked: [CatalogTrack] = catalog.tracks.filter { library.isLiked(trackId: $0.id) }
            if liked.isEmpty {
                ContentUnavailableView("Aún no te gusta ninguna canción", systemImage: "heart", description: Text("Toca el corazón en Reproduciendo para guardarla aquí."))
            } else {
                SurfaceList(items: liked) { track in
                    Button {
                        player.play(track, in: liked, from: "Canciones que te gustan")
                    } label: {
                        TrackRow(
                            title: track.title,
                            subtitle: track.artist,
                            artwork: ArtworkColors.forArtist(track.artistId, in: catalog),
                            origin: track.origin,
                            trailing: SlowModeFormat.duration(Double(track.duration)),
                            isCurrent: player.currentTrack?.id == track.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        case .playlists:
            if library.playlists.isEmpty {
                ContentUnavailableView("Sin playlists", systemImage: "music.note.list", description: Text("Crea una con el botón +."))
            } else {
                SurfaceList(items: library.playlists) { playlist in
                    Button {
                        let tracks: [CatalogTrack] = playlist.trackIds.compactMap { catalog.track(id: $0) }
                        if let first = tracks.first {
                            player.play(first, in: tracks, from: playlist.name)
                        }
                    } label: {
                        EntityRow(
                            title: playlist.name,
                            subtitle: "Por ti · \(playlist.trackIds.count) " + (playlist.trackIds.count == 1 ? "canción" : "canciones"),
                            leading: .gradient(AnyShapeStyle(Palette.pinkGradient), symbol: "music.note.list")
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        case .albums:
            SurfaceList(items: catalog.albums) { album in
                NavigationLink(value: AppRoute.artist(album.artistId)) {
                    EntityRow(
                        title: album.title,
                        subtitle: "\(album.artist) · \(album.trackCount) " + (album.trackCount == 1 ? "canción" : "canciones"),
                        leading: .artwork(ArtworkColors.forArtist(album.artistId, in: catalog)),
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                .disabled(catalog.artist(id: album.artistId) == nil)
            }
        case .artists:
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

/// Hoja "Importar o subir audio": copia los archivos elegidos a la app y lee sus metadatos.
struct ImportSheet: View {
    @Environment(LocalLibrary.self) private var localLibrary: LocalLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var showsPicker: Bool = false
    @State private var importOrigin: TrackOrigin = .localFile
    @State private var outcome: ImportOutcome?
    @State private var pickerError: String?

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

                if localLibrary.isImporting {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Importando…")
                        }
                    }
                }

                if let outcome {
                    Section("Resultado") {
                        Text(outcome.summary)
                            .textStyle(.body)
                        ForEach(Array(outcome.failures.enumerated()), id: \.offset) { _, failure in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(failure.fileName).textStyle(.body)
                                Text(failure.reason.message).textStyle(.caption)
                            }
                        }
                        if !outcome.duplicates.isEmpty {
                            Text("Ya estaban en tu biblioteca: " + outcome.duplicates.joined(separator: ", "))
                                .textStyle(.caption)
                        }
                    }
                }

                if let pickerError {
                    Section {
                        Text(pickerError).textStyle(.caption)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Importar o subir audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(outcome == nil ? "Cerrar" : "Hecho") { dismiss() }
                        .disabled(localLibrary.isImporting)
                }
            }
            .fileImporter(
                isPresented: $showsPicker,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    pickerError = nil
                    let origin: TrackOrigin = importOrigin
                    Task {
                        outcome = await localLibrary.importFiles(urls, origin: origin)
                    }
                case .failure:
                    pickerError = "No se pudo abrir el selector de archivos. Inténtalo de nuevo."
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(localLibrary.isImporting)
    }

    private func option(title: String, detail: String, symbol: String, origin: TrackOrigin) -> some View {
        Button {
            importOrigin = origin
            outcome = nil
            showsPicker = true
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
        .disabled(localLibrary.isImporting)
    }
}
