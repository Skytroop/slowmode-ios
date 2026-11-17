import SwiftUI

enum ArtistLayout: Hashable {
    case list, grid
}

/// "Todos los artistas": orden, lista/cuadrícula y chips de género.
struct ArtistDirectorySection: View {
    let artists: [CatalogArtist]
    let genres: [String]
    @Binding var selectedGenre: String?
    @Binding var sort: ArtistSort
    @Binding var layout: ArtistLayout
    @Environment(\.theme) private var theme: Theme

    var body: some View {
        let shown: [CatalogArtist] = ArtistDirectory.artists(artists, genre: selectedGenre, sort: sort)
        let maxPlays: Int = max(artists.map(\.plays).max() ?? 1, 1)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Todos los artistas")
                    .textStyle(.sectionTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("\(shown.count)")
                    .textStyle(.caption)
                    .monospacedDigit()
                Spacer(minLength: 8)
                sortMenu
                Picker("Vista", selection: $layout) {
                    Label("Lista", systemImage: "list.bullet").labelStyle(.iconOnly).tag(ArtistLayout.list)
                    Label("Cuadrícula", systemImage: "square.grid.2x2").labelStyle(.iconOnly).tag(ArtistLayout.grid)
                }
                .pickerStyle(.segmented)
                .frame(width: 96)
            }

            genreChips

            if shown.isEmpty {
                ContentUnavailableView(
                    "Sin artistas",
                    systemImage: "person.slash",
                    description: Text("No hay artistas de este género.")
                )
            } else if layout == .list {
                SurfaceList(items: shown) { artist in
                    NavigationLink(value: AppRoute.artist(artist.id)) {
                        ArtistListRow(artist: artist, maxPlays: maxPlays)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(shown) { artist in
                        NavigationLink(value: AppRoute.artist(artist.id)) {
                            ArtistGridCell(artist: artist, maxPlays: maxPlays)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Orden", selection: $sort) {
                ForEach(ArtistSort.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 44, height: 44)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Ordenar")
        .accessibilityValue(sort.title)
    }

    private var genreChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Chip(title: "Todos", isSelected: selectedGenre == nil) {
                        selectedGenre = nil
                    }
                    ForEach(genres, id: \.self) { genre in
                        Chip(title: genre, isSelected: selectedGenre == genre) {
                            selectedGenre = genre
                        }
                    }
                }
            }
        }
        .scrollClipDisabled()
    }
}

private struct GenrePill: View {
    let genre: String

    var body: some View {
        if genre == "Indie" {
            Pill(text: genre, background: Palette.periwinkle, foreground: Palette.ink)
        } else {
            Pill(text: genre)
        }
    }
}

/// Barra fina de afinidad (reproducciones relativas al más escuchado).
private struct AffinityBar: View {
    let fraction: Double

    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.08))
            .frame(height: 3)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Palette.periwinkle)
                        .frame(width: max(4, proxy.size.width * fraction))
                }
            }
            .accessibilityHidden(true)
    }
}

private struct ArtistListRow: View {
    let artist: CatalogArtist
    let maxPlays: Int

    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(initials: artist.initials, background: Color(hex: artist.color), foreground: Color(hex: artist.onColor))
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(artist.name)
                        .textStyle(.body)
                        .lineLimit(1)
                    GenrePill(genre: artist.genre)
                    Spacer(minLength: 4)
                    Text("\(artist.plays) reprod.")
                        .textStyle(.caption)
                        .monospacedDigit()
                }
                AffinityBar(fraction: Double(artist.plays) / Double(maxPlays))
            }
        }
        .padding(.vertical, 10)
        .frame(minHeight: 56)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(artist.name), \(artist.genre), \(artist.plays) reproducciones")
        .accessibilityAddTraits(.isButton)
    }
}

private struct ArtistGridCell: View {
    let artist: CatalogArtist
    let maxPlays: Int
    @Environment(\.theme) private var theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            InitialsAvatar(initials: artist.initials, background: Color(hex: artist.color), foreground: Color(hex: artist.onColor), size: 56)
            Text(artist.name)
                .textStyle(.body)
                .lineLimit(1)
            GenrePill(genre: artist.genre)
            Text("\(artist.plays) reproducciones")
                .textStyle(.caption)
                .monospacedDigit()
            AffinityBar(fraction: Double(artist.plays) / Double(maxPlays))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: .rect(cornerRadius: Radius.list))
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(artist.name), \(artist.genre), \(artist.plays) reproducciones")
        .accessibilityAddTraits(.isButton)
    }
}
