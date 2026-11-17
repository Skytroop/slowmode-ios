import Foundation
import Observation

/// Carga el catálogo de ejemplo y expone su estado (cargando / listo / error).
@MainActor
@Observable
final class CatalogStore {
    enum State: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private(set) var state: State = .loading
    private(set) var catalog: SampleCatalog = .empty

    init() {}

    func load() {
        state = .loading
        do {
            catalog = try SampleCatalog.load()
            state = .loaded
        } catch {
            state = .failed(String(describing: error))
        }
    }
}
