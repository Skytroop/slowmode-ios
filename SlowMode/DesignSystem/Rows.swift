import SwiftUI
import UIKit

/// Colores de una portada o avatar.
struct ArtworkColors: Equatable {
    let background: Color
    let foreground: Color

    init(background: Color, foreground: Color) {
        self.background = background
        self.foreground = foreground
    }

    init(hexBackground: String, hexForeground: String) {
        self.init(background: Color(hex: hexBackground), foreground: Color(hex: hexForeground))
    }

    static func forArtist(_ artistId: String, in catalog: SampleCatalog) -> ArtworkColors {
        let hex = catalog.artistColorHex(for: artistId)
        return ArtworkColors(hexBackground: hex.background, hexForeground: hex.foreground)
    }
}

/// Portada cuadrada de una pista: la imagen del archivo si la tiene; si no, color del artista + nota.
struct TrackArtwork: View {
    let colors: ArtworkColors
    var image: UIImage? = nil
    var size: CGFloat = 48
    var cornerRadius: CGFloat = Radius.tile

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.34, weight: .medium))
                    .foregroundStyle(colors.foreground.opacity(0.8))
            }
        }
            .frame(width: size, height: size)
            .background(colors.background)
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

/// Fila de canción: posición opcional, portada, título, subtítulo (con insignia de origen) y dato a la derecha.
struct TrackRow: View {
    let title: String
    let subtitle: String
    let artwork: ArtworkColors
    var rank: Int? = nil
    var origin: TrackOrigin? = nil
    var trailing: String? = nil
    var isCurrent: Bool = false
    var image: UIImage? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let rank {
                Text("\(rank)")
                    .textStyle(.caption)
                    .monospacedDigit()
                    .frame(minWidth: 22)
            }
            TrackArtwork(colors: artwork, image: image)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .textStyle(.body)
                    .foregroundStyle(isCurrent ? Palette.periwinkle : Palette.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let origin {
                        OriginBadge(origin: origin)
                    }
                    Text(subtitle)
                        .textStyle(.caption)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .textStyle(.caption)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 8)
        .frame(minHeight: 56)
        .contentShape(.rect)
    }
}

/// Fila genérica con avatar redondo o cuadrado y etiqueta de tipo (búsqueda, biblioteca).
struct EntityRow: View {
    let title: String
    let subtitle: String
    let leading: Leading
    var tag: String? = nil
    var showsChevron: Bool = false

    enum Leading {
        case avatar(initials: String, colors: ArtworkColors)
        case artwork(ArtworkColors)
        case gradient(AnyShapeStyle, symbol: String)
    }

    var body: some View {
        HStack(spacing: 12) {
            leadingView
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .textStyle(.body)
                    .lineLimit(1)
                Text(subtitle)
                    .textStyle(.caption)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let tag {
                Pill(text: tag)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 8)
        .frame(minHeight: 56)
        .contentShape(.rect)
    }

    @ViewBuilder
    private var leadingView: some View {
        switch leading {
        case .avatar(let initials, let colors):
            InitialsAvatar(initials: initials, background: colors.background, foreground: colors.foreground, size: 48)
        case .artwork(let colors):
            TrackArtwork(colors: colors)
        case .gradient(let style, let symbol):
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Palette.ink)
                .frame(width: 48, height: 48)
                .background(style, in: .rect(cornerRadius: Radius.tile))
                .accessibilityHidden(true)
        }
    }
}

/// Contenedor de lista sobre superficie de contenido (no cristal), con separadores finos.
struct SurfaceList<Item: Identifiable, Row: View>: View {
    let items: [Item]
    @ViewBuilder let row: (Item) -> Row
    @Environment(\.theme) private var theme: Theme

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(theme.separator)
                        .frame(height: 1)
                }
                row(item)
            }
        }
        .padding(.horizontal, 16)
        .background(theme.surface, in: .rect(cornerRadius: Radius.list))
    }
}

/// Título de sección con contador o acción opcional.
struct SectionHeader<Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .textStyle(.sectionTitle)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            accessory
        }
    }
}

extension SectionHeader where Accessory == EmptyView {
    init(title: String) {
        self.title = title
        self.accessory = EmptyView()
    }
}
