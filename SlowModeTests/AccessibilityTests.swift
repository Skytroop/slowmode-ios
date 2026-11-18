import Foundation
import Testing
@testable import SlowMode

/// Contraste WCAG AA (≥ 4,5:1 en texto normal) de las combinaciones que usa la app.
struct ContrastTests {
    private let background: String = "#08080A"
    private let oledBackground: String = "#000000"

    @Test func inkOnPastels() {
        for pastel in ["#B9C8F2", "#CBD6F8", "#AEBFF0", "#F1C4DF", "#F6D3E8", "#EDB9D8", "#D2BDB8", "#F4F1EA", "#C5D1F6"] {
            #expect(ColorContrast.ratio("#101014", pastel) >= 4.5, "Tinta sobre \(pastel)")
        }
    }

    @Test func lightTextOnDarkSurfaces() {
        for text in ["#F4F4F5", "#A3A3AD", "#D4D4D8", "#B9C8F2", "#F1C4DF"] {
            #expect(ColorContrast.ratio(text, background) >= 4.5, "\(text) sobre el fondo")
            #expect(ColorContrast.ratio(text, oledBackground) >= 4.5, "\(text) sobre negro OLED")
        }
        for dark in ["#3A3F78", "#2C2C34", "#17171C", "#1E1E23"] {
            #expect(ColorContrast.ratio("#F4F4F5", dark) >= 4.5, "Texto claro sobre \(dark)")
        }
    }

    @Test func secondaryTextOnTranslucentSurface() {
        // Superficie de contenido: rgba(24,24,30,0.58) sobre el fondo.
        let surface = ColorContrast.RGB(red: 24 / 255, green: 24 / 255, blue: 30 / 255)
            .over(ColorContrast.RGB(hex: background), opacity: 0.58)
        #expect(ColorContrast.ratio(ColorContrast.RGB(hex: "#A3A3AD"), surface) >= 4.5)
        // Pill neutra: blanco al 12 % sobre la superficie.
        let pill = ColorContrast.RGB(red: 1, green: 1, blue: 1).over(surface, opacity: 0.12)
        #expect(ColorContrast.ratio(ColorContrast.RGB(hex: "#D4D4D8"), pill) >= 4.5)
    }

    @Test func ratioMath() {
        #expect(abs(ColorContrast.ratio("#000000", "#FFFFFF") - 21) < 0.01)
        #expect(abs(ColorContrast.ratio("#777777", "#777777") - 1) < 0.0001)
    }
}

struct SpokenFormatTests {
    @Test func durations() {
        #expect(SlowModeFormat.spokenDuration(214) == "3 minutos 34 segundos")
        #expect(SlowModeFormat.spokenDuration(60) == "1 minuto")
        #expect(SlowModeFormat.spokenDuration(1) == "1 segundo")
        #expect(SlowModeFormat.spokenDuration(0) == "0 segundos")
    }

    @Test func settings() {
        #expect(SlowModeFormat.spokenTempo(0.85) == "velocidad 0,85")
        #expect(SlowModeFormat.spokenPitch(-2) == "2 semitonos más grave")
        #expect(SlowModeFormat.spokenPitch(1) == "1 semitono más agudo")
        #expect(SlowModeFormat.spokenPitch(0) == "tono original")
        #expect(SlowModeFormat.spokenSettings(tempo: 0.85, pitch: -2, reverb: 20) == "velocidad 0,85, 2 semitonos más grave, 20 % de reverb")
        #expect(SlowModeFormat.spokenBadge(for: SlowSettings(isEnabled: true, tempo: 0.85, pitch: -2)) == "Ralentizado: velocidad 0,85, 2 semitonos más grave")
        #expect(SlowModeFormat.spokenBadge(for: SlowSettings(isEnabled: false, tempo: 0.85)) == nil)
    }

    @Test func themeReducesTransparency() {
        let reduced = Theme(isOLED: false, reducesTransparency: true)
        let normal = Theme(isOLED: false)
        #expect(reduced.ambientOpacities(.standard).0 < normal.ambientOpacities(.standard).0)
    }
}
