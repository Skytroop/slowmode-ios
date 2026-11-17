import Foundation

/// Textos de Slow Mode y contadores, iguales en toda la app.
enum SlowModeFormat {
    private static let minus: String = "\u{2212}"

    /// 0.85 → "0.85×"
    static func tempo(_ tempo: Double) -> String {
        String(format: "%.2f×", locale: Locale(identifier: "en_US_POSIX"), tempo)
    }

    /// −2 → "−2 st", 0 → "0 st", 3 → "+3 st"
    static func pitch(_ semitones: Int) -> String {
        if semitones > 0 { return "+\(semitones) st" }
        if semitones < 0 { return "\(minus)\(-semitones) st" }
        return "0 st"
    }

    /// 20 → "20 % reverb"
    static func reverb(_ percent: Int) -> String {
        "\(percent) % reverb"
    }

    /// Resumen con solo lo que cambia: "0.85× · −2 st · 20 % reverb". `nil` si nada cambia.
    static func summary(tempo: Double, pitch: Int, reverb: Int) -> String? {
        var parts: [String] = []
        if abs(tempo - 1) >= 0.005 { parts.append(Self.tempo(tempo)) }
        if pitch != 0 { parts.append(Self.pitch(pitch)) }
        if reverb > 0 { parts.append(Self.reverb(reverb)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// 214 → "3:34"
    static func duration(_ seconds: Double) -> String {
        let total: Int = max(0, Int(seconds.rounded()))
        let secs: Int = total % 60
        return "\(total / 60):" + (secs < 10 ? "0\(secs)" : "\(secs)")
    }

    /// 0.85 → "15 % más lento", 1.15 → "15 % más rápido", 1 → "Velocidad original"
    static func speedChange(_ tempo: Double) -> String {
        let percent: Int = Int((abs(1 - tempo) * 100).rounded())
        if percent == 0 { return "Velocidad original" }
        return tempo < 1 ? "\(percent) % más lento" : "\(percent) % más rápido"
    }

    /// "15 % más lento · 3:34 pasa a ser 4:12"
    static func stretchSentence(duration seconds: Double, tempo: Double) -> String {
        let stretched: Double = SlowModeMath.stretchedDuration(seconds, tempo: tempo)
        return "\(speedChange(tempo)) · \(duration(seconds)) pasa a ser \(duration(stretched))"
    }

    /// 1988 → "1.988" (separador de miles siempre, también con 4 cifras).
    static func count(_ value: Int) -> String {
        let digits: [Character] = Array(String(abs(value)))
        var out: String = ""
        for (index, digit) in digits.enumerated() {
            if index > 0 && (digits.count - index) % 3 == 0 { out.append(".") }
            out.append(digit)
        }
        return (value < 0 ? minus : "") + out
    }

    /// 940 → "940", 12_400 → "12,4 k", 1_250_000 → "1,3 M"
    static func compact(_ value: Int) -> String {
        if value >= 1_000_000 { return oneDecimal(Double(value) / 1_000_000) + " M" }
        if value >= 1_000 { return oneDecimal(Double(value) / 1_000) + " k" }
        return String(value)
    }

    private static func oneDecimal(_ x: Double) -> String {
        let tenths: Int = Int((x * 10).rounded())
        if tenths % 10 == 0 { return String(tenths / 10) }
        return "\(tenths / 10),\(tenths % 10)"
    }
}
