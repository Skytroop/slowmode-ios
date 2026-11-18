import SwiftUI

/// Una playlist: reproducir, quitar canciones o eliminarla.
struct PlaylistView: View {
    let playlistID: UUID

    @Environment(CatalogStore.self) private var store: CatalogStore
    @Environment(LocalLibrary.self) private var localLibrary: LocalLibrary
    @Environment(PresetStore.self) private var presetStore: PresetStore
    @Environment(PlayerController.self) private var player: PlayerController
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDelete: Bool = false

    var body: some View {
        Group {
            if let playlist = localLibrary.playlist(id: playlistID) {
                let tracks: [CatalogTrack] = localLibrary.tracks(in: playlist)
                let catalog: SampleCatalog = localLibrary.userCatalog(community: store.catalog, myPresets: presetStore.communityPresets)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(spacing: 10) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 40, weight: .medium))
                                .foregroundStyle(Palette.ink)
                                .frame(width: 104, height: 104)
                                .background(Palette.pinkGradient, in: .rect(cornerRadius: Radius.card))
                                .accessibilityHidden(true)
                            Text(playlist.name)
                                .textStyle(.screenTitle)
                                .multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isHeader)
                            Text(tracks.count == 1 ? "1 canción" : "\(tracks.count) canciones")
                                .textStyle(.caption)
                            if let first = tracks.first {
                                Button {
                                    player.play(first, in: tracks, from: playlist.name)
                                } label: {
                                    Label("Reproducir", systemImage: "play.fill")
                                        .font(.headline)
                                        .foregroundStyle(Palette.ink)
                                        .padding(.horizontal, 28)
                                        .frame(minHeight: 52)
                                }
                                .buttonStyle(.plain)
                                .glassEffect(.regular.tint(Palette.periwinkle).interactive(), in: .capsule)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        if tracks.isEmpty {
                            ContentUnavailableView(
                                "Playlist vacía",
                                systemImage: "music.note",
                                description: Text("Añade canciones desde Reproduciendo o manteniendo pulsada una canción en Biblioteca.")
                            )
                        } else {
                            SurfaceList(items: tracks) { track in
                                Button {
                                    player.play(track, in: tracks, from: playlist.name)
                                } label: {
                                    TrackRow(
                                        title: track.title,
                                        subtitle: track.artist,
                                        artwork: ArtworkColors.forArtist(track.artistId, in: catalog),
                                        trailing: SlowModeFormat.duration(Double(track.duration)),
                                        isCurrent: player.currentTrack?.id == track.id,
                                        image: localLibrary.artwork(for: track.id),
                                        trailingSpoken: SlowModeFormat.spokenDuration(Double(track.duration))
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        localLibrary.remove(trackCatalogId: track.id, from: playlist)
                                    } label: {
                                        Label("Quitar de la playlist", systemImage: "minus.circle")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                confirmsDelete = true
                            } label: {
                                Label("Eliminar playlist", systemImage: "trash")
                            }
                        } label: {
                            Label("Más", systemImage: "ellipsis")
                        }
                    }
                }
                .confirmationDialog("¿Eliminar «\(playlist.name)»?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                    Button("Eliminar playlist", role: .destructive) {
                        dismiss()
                        localLibrary.delete(playlist)
                    }
                } message: {
                    Text("Las canciones siguen en tu biblioteca.")
                }
            } else {
                ContentUnavailableView("Playlist no encontrada", systemImage: "music.note.list")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.playlistView)
        .background(AmbientBackground())
        .navigationBarTitleDisplayMode(.inline)
    }
}
