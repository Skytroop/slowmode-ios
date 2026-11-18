import SwiftData
import SwiftUI

@main
struct SlowModeApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Track.self, SlowPreset.self, Playlist.self, PlayEvent.self)
        } catch {
            // Si el almacén no se puede abrir, la app arranca igualmente (sin guardar entre sesiones).
            let memory = ModelConfiguration(isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            container = try! ModelContainer(for: Track.self, SlowPreset.self, Playlist.self, PlayEvent.self, configurations: memory)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
