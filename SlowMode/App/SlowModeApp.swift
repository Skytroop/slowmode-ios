import SwiftData
import SwiftUI

@main
struct SlowModeApp: App {
    private let container: ModelContainer

    init() {
        let memory = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            if DemoContent.isEnabled {
                // Pruebas de interfaz: nunca tocan los datos guardados.
                container = try ModelContainer(for: Track.self, SlowPreset.self, Playlist.self, PlayEvent.self, configurations: memory)
            } else {
                container = try ModelContainer(for: Track.self, SlowPreset.self, Playlist.self, PlayEvent.self)
            }
        } catch {
            // Si el almacén no se puede abrir, la app arranca igualmente (sin guardar entre sesiones).
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
