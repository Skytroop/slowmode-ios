import SwiftUI

/// Hoja "Repetir fragmento": elige inicio y fin (tiempos de la canción original).
struct LoopSheet: View {
    @Environment(PlayerController.self) private var player: PlayerController
    @Environment(\.dismiss) private var dismiss
    @State private var start: Double
    @State private var end: Double

    init(start: Double, end: Double) {
        _start = State(initialValue: start)
        _end = State(initialValue: end)
    }

    private var length: Double { end - start }
    private var isValid: Bool { length >= PlayerController.minimumLoopLength }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    boundRow(title: "Inicio", value: $start)
                    boundRow(title: "Fin", value: $end)
                } footer: {
                    if isValid {
                        Text("Se repetirán \(SlowModeFormat.duration(length)) (\(SlowModeFormat.duration(start))–\(SlowModeFormat.duration(end))) hasta que lo quites. Los tiempos son los de la canción original.")
                    } else {
                        Text("El fin tiene que ir al menos 1 segundo después del inicio.")
                            .foregroundStyle(Palette.pink)
                    }
                }

                Section {
                    Button {
                        if player.setLoop(start: start, end: end) { dismiss() }
                    } label: {
                        Label("Repetir fragmento", systemImage: "repeat")
                            .frame(minHeight: 44)
                    }
                    .disabled(!isValid)
                    .accessibilityHint(isValid ? "" : "El fin tiene que ir al menos 1 segundo después del inicio")

                    if player.loopRange != nil {
                        Button(role: .destructive) {
                            player.clearLoop()
                            dismiss()
                        } label: {
                            Label("Quitar fragmento", systemImage: "xmark")
                                .frame(minHeight: 44)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Repetir fragmento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func boundRow(title: String, value: Binding<Double>) -> some View {
        let maximum: Double = max(player.duration, 1)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .textStyle(.body)
                Spacer()
                Text(SlowModeFormat.duration(value.wrappedValue))
                    .font(.title3.weight(.medium))
                    .monospacedDigit()
            }
            HStack(spacing: 4) {
                Button {
                    value.wrappedValue = max(0, value.wrappedValue - 1)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(title): un segundo antes")

                Slider(value: value, in: 0...maximum, step: 1) {
                    Text(title)
                }
                .accessibilityValue(SlowModeFormat.duration(value.wrappedValue))

                Button {
                    value.wrappedValue = min(maximum, value.wrappedValue + 1)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(title): un segundo después")
            }
            Button {
                value.wrappedValue = player.position.rounded(.down)
            } label: {
                Label("Usar posición actual (\(SlowModeFormat.duration(player.position.rounded(.down))))", systemImage: "scope")
                    .font(.subheadline)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}
