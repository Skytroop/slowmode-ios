import SwiftUI

extension Color {
    /// `#RRGGBB` → Color. Si el texto no es válido devuelve gris medio.
    init(hex: String) {
        let cleaned: String = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        let value: UInt64 = UInt64(cleaned, radix: 16) ?? 0x808080
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Colores de `docs/SPEC.md` §1.
enum Palette {
    // Periwinkle
    static var periwinkleStart: Color { Color(hex: "#CBD6F8") }
    static var periwinkleEnd: Color { Color(hex: "#AEBFF0") }
    static var periwinkle: Color { Color(hex: "#B9C8F2") }

    // Rosa
    static var pinkStart: Color { Color(hex: "#F6D3E8") }
    static var pinkEnd: Color { Color(hex: "#EDB9D8") }
    static var pink: Color { Color(hex: "#F1C4DF") }

    // Neutros de apoyo
    static var sand: Color { Color(hex: "#D2BDB8") }
    static var cream: Color { Color(hex: "#F4F1EA") }
    static var indigo: Color { Color(hex: "#3A3F78") }
    static var graphite: Color { Color(hex: "#2C2C34") }

    // Texto
    static var textPrimary: Color { Color(hex: "#F4F4F5") }
    static var textSecondary: Color { Color(hex: "#A3A3AD") }
    static var textTertiary: Color { Color(hex: "#D4D4D8") }
    /// Tinta sobre fondos pastel.
    static var ink: Color { Color(hex: "#101014") }

    /// Degradado a 145° (como en CSS: de arriba-izquierda a abajo-derecha).
    static func gradient145(_ start: Color, _ end: Color) -> LinearGradient {
        LinearGradient(
            colors: [start, end],
            startPoint: UnitPoint(x: 0.213, y: 0.090),
            endPoint: UnitPoint(x: 0.787, y: 0.910)
        )
    }

    static var periwinkleGradient: LinearGradient { gradient145(periwinkleStart, periwinkleEnd) }
    static var pinkGradient: LinearGradient { gradient145(pinkStart, pinkEnd) }
}

/// Radios de esquina.
enum Radius {
    static let card: CGFloat = 28
    static let list: CGFloat = 24
    static let tile: CGFloat = 12
}
