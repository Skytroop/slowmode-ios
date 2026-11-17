import SwiftUI

struct RootView: View {
    var body: some View {
        ThemedRoot {
            DesignCatalogView()
        }
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
