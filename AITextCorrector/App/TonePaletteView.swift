import SwiftUI

struct TonePaletteView: View {
    @ObservedObject var settingsStore: SettingsStore
    let selectionPreview: String
    let onUseDefault: () -> Void
    let onSelectTone: (String) -> Void
    let onSetDefaultTone: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Corregir texto")
                        .font(.headline)
                    Text("Predeterminado: \(currentDefaultTone.title)")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(selectionPreview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

            Button {
                onUseDefault()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Usar tono predeterminado")
                    Spacer()
                    Text(currentDefaultTone.title)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(ToneOption.presets) { tone in
                        HStack(spacing: 10) {
                            Button {
                                onSelectTone(tone.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tone.title)
                                            .foregroundStyle(.primary)
                                        if tone.id == settingsStore.settings.defaultTone {
                                            Text("Tono predeterminado actual")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(0.05))
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                onSetDefaultTone(tone.id)
                            } label: {
                                Image(systemName: tone.id == settingsStore.settings.defaultTone ? "star.fill" : "star")
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.borderless)
                            .help("Dejar este tono como predeterminado")
                        }
                    }
                }
            }
            .frame(maxHeight: 280)
        }
        .padding(16)
        .frame(width: 380)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }

    private var currentDefaultTone: ToneOption {
        ToneOption.presets.first(where: { $0.id == settingsStore.settings.defaultTone })
            ?? ToneOption(id: settingsStore.settings.defaultTone, title: settingsStore.settings.defaultTone)
    }
}

