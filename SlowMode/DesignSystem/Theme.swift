import SwiftUI

enum AppStorageKey {
    /// Apariencia "Negro puro (OLED)".
    static let oledBlack: String = "oledBlack"
}

/// Apariencia activa: tema oscuro o negro puro (OLED).
struct Theme: Sendable, Equatable {
    let isOLED: Bool

    static let dark: Theme = Theme(isOLED: false)
    static let oled: Theme = Theme(isOLED: true)

    /// Fondo de la app.
    var background: Color { isOLED ? .black : Color(hex: "#08080A") }

    /// Superficie de contenido (tarjetas y listas no destacadas). No es cristal.
    var surface: Color {
        isOLED ? Color.white.opacity(0.04) : Color(.sRGB, red: 24 / 255, green: 24 / 255, blue: 30 / 255, opacity: 0.58)
    }

    /// Separador fino entre filas.
    var separator: Color { Color.white.opacity(0.06) }

    /// Opacidad de las tres manchas del fondo ambiental (periwinkle, rosa, índigo).
    func ambientOpacities(_ intensity: AmbientIntensity) -> (Double, Double, Double) {
        switch (intensity, isOLED) {
        case (.standard, false): return (0.18, 0.14, 0.38)
        case (.standard, true): return (0.07, 0.05, 0.10)
        case (.player, false): return (0.40, 0.32, 0.60)
        case (.player, true): return (0.34, 0.24, 0.30)
        }
    }
}

enum AmbientIntensity: Sendable {
    /// Pantallas normales.
    case standard
    /// Reproduciendo: más intenso y con el color de la portada.
    case player
}

extension EnvironmentValues {
    @Entry var theme: Theme = .dark
}

/// Aplica el tema guardado en `@AppStorage("oledBlack")` a todo lo que contiene.
struct ThemedRoot<Content: View>: View {
    @AppStorage(AppStorageKey.oledBlack) private var oledBlack: Bool = false
    @ViewBuilder let content: Content

    var body: some View {
        content
            .environment(\.theme, oledBlack ? .oled : .dark)
            .preferredColorScheme(.dark)
            .tint(Palette.periwinkle)
    }
}
