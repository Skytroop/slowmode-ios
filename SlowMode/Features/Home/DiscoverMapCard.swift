import SwiftUI

/// Mapa "Descubre": tu artista más escuchado en el centro y 6 parecidos alrededor sobre anillos.
struct DiscoverMapCard: View {
    let catalog: SampleCatalog

    /// Ángulo (grados) y diámetro de cada burbuja, como en el prototipo.
    private let spots: [(angle: Double, size: CGFloat)] = [
        (270, 62), (340, 52), (30, 60), (90, 54), (150, 54), (200, 52),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Descubre")
                    .textStyle(.sectionTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("Tus artistas, por cercanía de género y escuchas")
                    .font(.footnote)
            }
            .foregroundStyle(Palette.ink)

            GeometryReader { proxy in
                let width: CGFloat = proxy.size.width
                let height: CGFloat = proxy.size.height
                let center: CGPoint = CGPoint(x: width / 2, y: height / 2)
                let radiusX: CGFloat = width * 0.36
                let radiusY: CGFloat = height * 0.36

                ZStack {
                    ForEach(1...3, id: \.self) { ring in
                        Ellipse()
                            .stroke(Palette.ink.opacity(0.12), lineWidth: 1)
                            .frame(width: radiusX * 2 * CGFloat(ring) / 3, height: radiusY * 2 * CGFloat(ring) / 3)
                            .position(center)
                    }

                    GlassEffectContainer(spacing: 12) {
                        ZStack {
                            if let top = catalog.artist(id: catalog.home.discover.centerArtistId) {
                                bubble(top, label: top.name, size: 96)
                                    .accessibilityLabel("\(top.name), tu artista más escuchado")
                                    .position(center)
                            }
                            ForEach(Array(catalog.home.discover.similar.prefix(spots.count).enumerated()), id: \.element.artistId) { index, similar in
                                if let artist = catalog.artist(id: similar.artistId) {
                                    let spot = spots[index]
                                    let theta: Double = spot.angle * Double.pi / 180
                                    bubble(artist, label: firstName(artist.name), size: spot.size)
                                        .accessibilityLabel("\(artist.name), \(artist.genre), \(similar.affinity) % de afinidad")
                                        .position(
                                            x: center.x + radiusX * CGFloat(cos(theta)),
                                            y: center.y + radiusY * CGFloat(sin(theta))
                                        )
                                }
                            }
                        }
                        .frame(width: width, height: height)
                    }
                }
            }
            .frame(height: 300)
        }
        .padding(20)
        .background(Palette.periwinkleGradient, in: .rect(cornerRadius: Radius.card))
    }

    private func firstName(_ name: String) -> String {
        String(name.split(separator: " ").first ?? Substring(name))
    }

    private func bubble(_ artist: CatalogArtist, label: String, size: CGFloat) -> some View {
        NavigationLink(value: AppRoute.artist(artist.id)) {
            Text(label)
                .font(.system(size > 80 ? Font.TextStyle.subheadline : Font.TextStyle.caption, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(6)
                .foregroundStyle(Color(hex: artist.onColor))
                .frame(width: size, height: size)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Color(hex: artist.color).opacity(0.84)).interactive(), in: .circle)
    }
}
