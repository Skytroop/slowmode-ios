import Foundation

/// Contraste WCAG entre colores de la paleta (texto normal ≥ 4,5:1). Se comprueba en los tests.
enum ColorContrast {
    struct RGB: Equatable, Sendable {
        let red: Double
        let green: Double
        let blue: Double

        init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        init(hex: String) {
            let cleaned: String = hex.replacingOccurrences(of: "#", with: "")
            let value: UInt64 = UInt64(cleaned, radix: 16) ?? 0
            self.init(
                red: Double((value >> 16) & 0xFF) / 255,
                green: Double((value >> 8) & 0xFF) / 255,
                blue: Double(value & 0xFF) / 255
            )
        }

        /// Este color con `opacity` sobre `background`.
        func over(_ background: RGB, opacity: Double) -> RGB {
            RGB(
                red: red * opacity + background.red * (1 - opacity),
                green: green * opacity + background.green * (1 - opacity),
                blue: blue * opacity + background.blue * (1 - opacity)
            )
        }

        var luminance: Double {
            func channel(_ c: Double) -> Double {
                c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
        }
    }

    static func ratio(_ a: RGB, _ b: RGB) -> Double {
        let la: Double = a.luminance
        let lb: Double = b.luminance
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    static func ratio(_ a: String, _ b: String) -> Double {
        ratio(RGB(hex: a), RGB(hex: b))
    }
}
