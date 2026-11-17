import SwiftUI

struct RootView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 56, weight: .light))
                .accessibilityHidden(true)
            Text(AppInfo.name)
                .font(.largeTitle.weight(.medium))
            Text("Versión \(AppInfo.version)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }
}

enum AppInfo {
    static let name: String = "Slow Mode"
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}

#Preview {
    RootView()
}
