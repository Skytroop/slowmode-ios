import Foundation

enum PresetFilter: String, CaseIterable, Identifiable, Sendable {
    case all, slowed, spedUp, pitchOnly, liked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Todos"
        case .slowed: return "Ralentizado"
        case .spedUp: return "Acelerado"
        case .pitchOnly: return "Solo tono"
        case .liked: return "Me gusta"
        }
    }
}

enum PresetSort: String, CaseIterable, Identifiable, Sendable {
    case popular, recent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .popular: return "Popular"
        case .recent: return "Recientes"
        }
    }
}

enum PresetQuery {
    static func apply(
        _ presets: [CommunityPreset],
        filter: PresetFilter,
        sort: PresetSort,
        likedIds: Set<String>
    ) -> [CommunityPreset] {
        let filtered: [CommunityPreset] = presets.filter { preset in
            switch filter {
            case .all: return true
            case .slowed: return preset.tempo < 1
            case .spedUp: return preset.tempo > 1
            case .pitchOnly: return preset.tempo == 1
            case .liked: return likedIds.contains(preset.id)
            }
        }
        switch sort {
        case .popular:
            return filtered.sorted { $0.uses > $1.uses }
        case .recent:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        }
    }

    /// Los `count` más usados.
    static func top(_ presets: [CommunityPreset], count: Int) -> [CommunityPreset] {
        Array(presets.sorted { $0.uses > $1.uses }.prefix(count))
    }
}
