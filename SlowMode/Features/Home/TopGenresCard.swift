import SwiftUI

/// Gráfico de burbujas con los géneros más escuchados. Tocar uno filtra la lista de artistas.
struct TopGenresCard: View {
    let genres: [GenreShare]
    @Binding var selectedGenre: String?
    @Environment(\.theme) private var theme: Theme

    /// Posición y diámetro sobre una caja de 200×175, como en el prototipo.
    private let spots: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (60, 58, 92), (148, 46, 76), (132, 122, 76), (62, 134, 50),
    ]
    private let fills: [Color] = [Palette.sand, Palette.periwinkle, Palette.pink, Palette.graphite]
    private let inks: [Color] = [Palette.ink, Palette.ink, Palette.ink, Palette.textPrimary]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top géneros")
                .textStyle(.sectionTitle)
                .accessibilityAddTraits(.isHeader)

            if genres.isEmpty {
                Text("Escucha un poco de tu música y aquí verás tus géneros.")
                    .textStyle(.caption)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            } else {
            GeometryReader { proxy in
                let scale: CGFloat = proxy.size.width / 200
                ZStack {
                    ForEach(Array(genres.prefix(spots.count).enumerated()), id: \.element.genre) { index, share in
                        let spot = spots[index]
                        let isSelected: Bool = selectedGenre == share.genre
                        Button {
                            selectedGenre = isSelected ? nil : share.genre
                        } label: {
                            VStack(spacing: 0) {
                                Text(share.genre)
                                    .font(.caption2.weight(.semibold))
                                Text("\(share.percent) %")
                                    .font(.caption.weight(.light))
                                    .monospacedDigit()
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(4)
                            .foregroundStyle(inks[index])
                            .frame(width: max(46, spot.size * scale), height: max(46, spot.size * scale))
                            .background(fills[index].opacity(0.9), in: .circle)
                            .overlay {
                                if isSelected {
                                    Circle().strokeBorder(Palette.textPrimary, lineWidth: 3)
                                }
                            }
                            .contentShape(.circle)
                        }
                        .buttonStyle(.plain)
                        .position(x: spot.x * scale, y: spot.y * scale)
                        .accessibilityLabel("\(share.genre), \(share.percent) %")
                        .accessibilityHint("Filtra la lista de artistas")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
            .aspectRatio(200.0 / 175.0, contentMode: .fit)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: .rect(cornerRadius: Radius.card))
    }
}
