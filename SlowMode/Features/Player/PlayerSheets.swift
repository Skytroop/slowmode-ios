import AVKit
import SwiftUI

/// Botón del sistema para elegir la salida de audio (AirPlay, Bluetooth…).
struct RoutePickerButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = UIColor(Palette.textPrimary)
        view.activeTintColor = UIColor(Palette.periwinkle)
        view.prioritizesVideoDevices = false
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

/// Hoja "A continuación": pista actual y cola.
struct QueueSheet: View {
    @Environment(PlayerController.self) private var player: PlayerController
    @Environment(CatalogStore.self) private var store: CatalogStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let current = player.currentTrack {
                    Section("Sonando") {
                        row(current)
                    }
                }
                Section("A continuación") {
                    if player.upNext.isEmpty {
                        Text("No hay más pistas en la cola.")
                            .foregroundStyle(Palette.textSecondary)
                    } else {
                        ForEach(player.upNext) { track in
                            Button {
                                player.play(track, in: player.queue, from: player.sourceTitle)
                            } label: {
                                row(track)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("A continuación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ track: CatalogTrack) -> some View {
        TrackRow(
            title: track.title,
            subtitle: track.artist,
            artwork: ArtworkColors.forArtist(track.artistId, in: store.catalog),
            trailing: SlowModeFormat.duration(Double(track.duration)),
            isCurrent: player.currentTrack?.id == track.id
        )
    }
}

/// Hoja "Añadir a playlist": playlists existentes y "Nueva playlist".
struct AddToPlaylistSheet: View {
    @Environment(PlayerController.self) private var player: PlayerController
    @Environment(LibraryStore.self) private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var isNaming: Bool = false
    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        name = ""
                        isNaming = true
                    } label: {
                        Label("Nueva playlist", systemImage: "plus")
                            .frame(minHeight: 44)
                    }
                }
                Section("Tus playlists") {
                    if library.playlists.isEmpty {
                        Text("Aún no tienes playlists.")
                            .foregroundStyle(Palette.textSecondary)
                    }
                    ForEach(library.playlists) { playlist in
                        Button {
                            add(to: playlist.id)
                        } label: {
                            HStack {
                                Text(playlist.name)
                                Spacer()
                                Text("\(playlist.trackIds.count)")
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.textSecondary)
                            }
                            .frame(minHeight: 44)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Añadir a playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .alert("Nueva playlist", isPresented: $isNaming) {
                TextField("Nombre", text: $name)
                Button("Crear") {
                    if let playlist = library.createPlaylist(named: name) {
                        add(to: playlist.id)
                    }
                }
                Button("Cancelar", role: .cancel) {}
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func add(to playlistId: UUID) {
        if let track = player.currentTrack {
            library.add(trackId: track.id, toPlaylist: playlistId)
        }
        dismiss()
    }
}

/// Presets de la comunidad para la pista que suena.
struct TrackPresetsSheet: View {
    let track: CatalogTrack
    @Environment(CatalogStore.self) private var store: CatalogStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                PresetListSection(
                    presets: store.catalog.presets(forTrack: track),
                    showsArtist: false,
                    emptyMessage: "Nadie ha compartido presets de «\(track.title)» todavía."
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .navigationTitle("Presets de «\(track.title)»")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
