import SwiftUI

/// Muestrario temporal del sistema de diseño (Fase 0) para revisarlo en el iPhone.
/// Se sustituye por el `TabView` en la Fase 1.
struct DesignCatalogView: View {
    @Environment(\.theme) private var theme: Theme
    @State private var catalog: SampleCatalog?
    @State private var loadError: String?
    @State private var selectedChip: String = "Todos"
    @State private var ambientMoving: Bool = false

    private let chips: [String] = ["Todos", "Indie", "Electrónica", "Dream Pop", "R&B"]

    var body: some View {
        ZStack {
            AmbientBackground(isMoving: ambientMoving)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    cards
                    chipRow
                    pills
                    surfaceList
                    dataSummary
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
        }
        .foregroundStyle(Palette.textPrimary)
        .task { load() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sistema de diseño · Fase 0")
                    .textStyle(.caption)
                Text("Tu escucha")
                    .textStyle(.screenTitle)
            }
            Spacer()
            OLEDToggleButton()
        }
    }

    private var cards: some View {
        HStack(spacing: 12) {
            ContentCard(fill: AnyShapeStyle(Palette.periwinkleGradient)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(SlowModeFormat.count(catalog?.home.songsPlayed ?? 1988))
                        .textStyle(.bigNumber)
                    Text("Canciones escuchadas")
                        .font(.footnote)
                }
                .foregroundStyle(Palette.ink)
            }
            ContentCard(fill: AnyShapeStyle(Palette.pinkGradient)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(catalog?.home.streakDays ?? 23)")
                        .textStyle(.bigNumber)
                    Text("Días de racha")
                        .font(.footnote)
                }
                .foregroundStyle(Palette.ink)
            }
        }
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(chips, id: \.self) { chip in
                        Chip(title: chip, isSelected: chip == selectedChip) {
                            selectedChip = chip
                        }
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    private var pills: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pills e insignias").textStyle(.sectionTitle)
            PresetPills(tempo: 0.85, pitch: -2, reverb: 20)
            PresetPills(tempo: 1.15, pitch: 2, reverb: 0)
            HStack(spacing: 6) {
                OriginBadge(origin: .localFile)
                OriginBadge(origin: .originalUpload)
            }
            Text(SlowModeFormat.stretchSentence(duration: 214, tempo: 0.85))
                .textStyle(.caption)
            Toggle("Mover el fondo ambiental", isOn: $ambientMoving)
                .frame(minHeight: 44)
        }
    }

    private var surfaceList: some View {
        VStack(spacing: 0) {
            ForEach(Array((catalog?.artists.prefix(4) ?? []).enumerated()), id: \.element.id) { index, artist in
                HStack(spacing: 12) {
                    InitialsAvatar(
                        initials: artist.initials,
                        background: Color(hex: artist.color),
                        foreground: Color(hex: artist.onColor)
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(artist.name).textStyle(.body)
                        Text("\(artist.plays) reproducciones").textStyle(.caption)
                    }
                    Spacer()
                    Pill(text: artist.genre)
                }
                .padding(.vertical, 10)
                .overlay(alignment: .top) {
                    if index > 0 {
                        theme.separator.frame(height: 1)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 16)
        .background(theme.surface, in: .rect(cornerRadius: Radius.list))
    }

    @ViewBuilder
    private var dataSummary: some View {
        if let catalog {
            Text("Datos de ejemplo: \(catalog.artists.count) artistas · \(catalog.tracks.count) pistas · \(catalog.presets.count) presets · \(catalog.mixes.count) mezclas")
                .textStyle(.caption)
        } else if let loadError {
            VStack(alignment: .leading, spacing: 8) {
                Text("No se pudieron cargar los datos de ejemplo").textStyle(.body)
                Text(loadError).textStyle(.caption)
                Button("Reintentar") { load() }
                    .buttonStyle(.glass)
            }
        } else {
            ProgressView()
        }
    }

    private func load() {
        do {
            catalog = try SampleCatalog.load()
            loadError = nil
        } catch {
            loadError = String(describing: error)
        }
    }
}

#Preview {
    ThemedRoot { DesignCatalogView() }
}
