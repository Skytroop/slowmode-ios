import SwiftUI

/// Estilos de texto. Todos parten de estilos del sistema, así que respetan Dynamic Type.
enum AppTextStyle {
    /// Cifras grandes (contadores de Inicio): peso light y tracking negativo.
    case bigNumber
    /// Títulos de pantalla.
    case screenTitle
    /// Títulos de sección y tarjeta.
    case sectionTitle
    /// Texto de fila.
    case body
    /// Línea secundaria.
    case caption
    /// Texto de pills y chips.
    case label
}

private struct TextStyleModifier: ViewModifier {
    let style: AppTextStyle

    func body(content: Content) -> some View {
        switch style {
        case .bigNumber:
            content
                .font(.system(.largeTitle, weight: .light))
                .tracking(-1.2)
                .monospacedDigit()
        case .screenTitle:
            content
                .font(.system(.largeTitle, weight: .medium))
                .tracking(-0.6)
        case .sectionTitle:
            content.font(.system(.title3, weight: .semibold))
        case .body:
            content.font(.system(.body, weight: .medium))
        case .caption:
            content
                .font(.system(.subheadline))
                .foregroundStyle(Palette.textSecondary)
        case .label:
            content
                .font(.system(.footnote, weight: .medium))
                .monospacedDigit()
        }
    }
}

extension View {
    func textStyle(_ style: AppTextStyle) -> some View {
        modifier(TextStyleModifier(style: style))
    }
}
