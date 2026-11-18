import SwiftUI

struct HomeView: View {
    @Environment(CatalogStore.self) private var store: CatalogStore
    @Environment(LocalLibrary.self) private var localLibrary: LocalLibrary
    @Environment(AppNavigation.self) private var navigation: AppNavigation
    @State private var selectedGenre: String?
    @State private var sort: ArtistSort = .plays
    @State private var layout: ArtistLayout = .list

    var body: some View {
        let catalog: SampleCatalog = localLibrary.userCatalog(community: store.catalog, myPresets: [])

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HomeHeader(trackCount: catalog.home.trackCount)
                if catalog.tracks.isEmpty {
                    ContentUnavailableView {
                        Label("Importa tu música para empezar", systemImage: "music.note")
                    } description: {
                        Text("Tus artistas, géneros y estadísticas aparecerán aquí a medida que escuches.")
                    } actions: {
                        Button("Importar") { navigation.openImport() }
                            .buttonStyle(.glassProminent)
                    }
                    .padding(.top, 40)
                } else {
                    if catalog.artist(id: catalog.home.discover.centerArtistId) != nil {
                        DiscoverMapCard(catalog: catalog)
                    }
                    HStack(alignment: .top, spacing: 12) {
                        TopGenresCard(genres: catalog.home.topGenres, selectedGenre: $selectedGenre)
                        VStack(spacing: 12) {
                            SongsPlayedCard(count: catalog.home.songsPlayed)
                            StreakCard(days: catalog.home.streakDays)
                        }
                    }
                    ArtistDirectorySection(
                        artists: catalog.artists,
                        genres: catalog.genres,
                        selectedGenre: $selectedGenre,
                        sort: $sort,
                        layout: $layout
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(AmbientBackground())
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct HomeHeader: View {
    let trackCount: Int

    private var monthName: String {
        let month: String = Date.now.formatted(.dateTime.month(.wide).locale(Locale(identifier: "es_ES")))
        return month.prefix(1).uppercased() + month.dropFirst()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(monthName) · \(trackCount) pistas en este iPhone")
                    .textStyle(.caption)
                Text("Tu escucha")
                    .textStyle(.screenTitle)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 8)
            OLEDToggleButton()
        }
        .padding(.top, 8)
    }
}

private struct SongsPlayedCard: View {
    let count: Int

    var body: some View {
        ContentCard(fill: AnyShapeStyle(Palette.pinkGradient)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(SlowModeFormat.count(count))
                    .textStyle(.bigNumber)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("Canciones escuchadas")
                    .font(.footnote.weight(.medium))
            }
            .foregroundStyle(Palette.ink)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct StreakCard: View {
    let days: Int
    @Environment(\.theme) private var theme: Theme

    var body: some View {
        ContentCard(fill: AnyShapeStyle(theme.surface)) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Racha")
                    .textStyle(.caption)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(days)")
                        .textStyle(.bigNumber)
                    Text(days == 1 ? "día" : "días")
                        .font(.footnote.weight(.medium))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
