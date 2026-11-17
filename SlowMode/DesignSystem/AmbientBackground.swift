import SwiftUI

/// Fondo ambiental: manchas de color muy desenfocadas detrás del contenido.
/// En Reproduciendo usa los colores de la portada y se mueve despacio mientras suena.
struct AmbientBackground: View {
    var intensity: AmbientIntensity = .standard
    /// Colores de las tres manchas. Por defecto periwinkle, rosa e índigo.
    var colors: [Color] = [Palette.periwinkleEnd, Palette.pinkEnd, Palette.indigo]
    /// Si es `true` (está sonando), las manchas se desplazan lentamente.
    var isMoving: Bool = false

    @Environment(\.theme) private var theme: Theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isMoving || reduceMotion)) { context in
                let t: Double = context.date.timeIntervalSinceReferenceDate * 0.14
                let drift: CGSize = (isMoving && !reduceMotion)
                    ? CGSize(width: 28 * sin(t), height: 22 * cos(t))
                    : .zero
                let opacities: (Double, Double, Double) = theme.ambientOpacities(intensity)
                let w: CGFloat = proxy.size.width
                let h: CGFloat = proxy.size.height

                ZStack {
                    theme.background
                    blob(color(0), opacity: opacities.0, size: w * 1.08)
                        .position(x: w * 0.205, y: h * 0.142)
                        .offset(drift)
                    blob(color(1), opacity: opacities.1, size: w * 0.92)
                        .position(x: w * 0.923, y: h * 0.569)
                        .offset(CGSize(width: -drift.width, height: -drift.height))
                    blob(color(2), opacity: opacities.2, size: w * 1.03)
                        .position(x: w * 0.538, y: h * 0.929)
                        .offset(drift)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func color(_ index: Int) -> Color {
        colors.indices.contains(index) ? colors[index] : Palette.indigo
    }

    private func blob(_ color: Color, opacity: Double, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 70)
            .opacity(opacity)
    }
}
