import SwiftUI

/// Etiqueta en cápsula para contenido (velocidad, tono, género…). No es un control: sin cristal.
struct Pill: View {
    let text: String
    var background: Color = Color.white.opacity(0.12)
    var foreground: Color = Palette.textTertiary

    var body: some View {
        Text(text)
            .textStyle(.label)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(foreground)
            .background(background, in: .capsule)
    }
}

/// Pills de un preset: velocidad (periwinkle, rosa si > 1), tono y reverb (solo si > 0).
struct PresetPills: View {
    let tempo: Double
    let pitch: Int
    let reverb: Int

    var body: some View {
        HStack(spacing: 6) {
            Pill(
                text: SlowModeFormat.tempo(tempo),
                background: tempo > 1 ? Palette.pink : Palette.periwinkle,
                foreground: Palette.ink
            )
            Pill(text: SlowModeFormat.pitch(pitch))
            if reverb > 0 {
                Pill(text: SlowModeFormat.reverb(reverb))
            }
        }
    }
}

/// Chip seleccionable (filtros, ámbitos). Es un control: lleva cristal.
/// Ponlos dentro de un `GlassEffectContainer` cuando vayan en fila.
struct Chip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .textStyle(.label)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(minHeight: 34)
                .foregroundStyle(isSelected ? Palette.ink : Palette.textPrimary)
                .glassEffect(
                    isSelected ? Glass.regular.tint(Palette.textPrimary.opacity(0.9)).interactive() : Glass.regular.interactive(),
                    in: .capsule
                )
                .padding(.vertical, 5)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Insignia de origen de una pista: "Archivo local" (neutra) u "Original subido" (rosa).
struct OriginBadge: View {
    let origin: TrackOrigin

    var body: some View {
        switch origin {
        case .localFile:
            Pill(text: "Archivo local")
        case .originalUpload:
            Pill(text: "Original subido", background: Palette.pink.opacity(0.92), foreground: Palette.ink)
        }
    }
}

/// Avatar circular con iniciales.
struct InitialsAvatar: View {
    let initials: String
    let background: Color
    let foreground: Color
    var size: CGFloat = 44

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.36, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(background, in: .circle)
            .accessibilityHidden(true)
    }
}

/// Botón de luna que alterna la apariencia "Negro puro (OLED)".
struct OLEDToggleButton: View {
    @AppStorage(AppStorageKey.oledBlack) private var oledBlack: Bool = false

    var body: some View {
        Button {
            oledBlack.toggle()
        } label: {
            Image(systemName: oledBlack ? "moon.fill" : "moon")
                .font(.system(.body, weight: .medium))
                .foregroundStyle(oledBlack ? Palette.periwinkle : Palette.textPrimary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Negro puro (OLED)")
        .accessibilityValue(oledBlack ? "Activado" : "Desactivado")
    }
}

/// Tarjeta de contenido: color sólido o degradado pastel, nunca cristal.
struct ContentCard<Content: View>: View {
    var fill: AnyShapeStyle
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: .rect(cornerRadius: Radius.card))
    }
}
