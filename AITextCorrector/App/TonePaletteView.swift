import SwiftUI

// MARK: - Mode

enum PaletteMode: Equatable {
    /// Opened via shortcut / shortcut: a text selection was already captured.
    case selection(text: String)
    /// Opened from the menu bar with no prior selection: user types/pastes text here.
    case directInput
}

// MARK: - View

struct TonePaletteView: View {
    @ObservedObject var settingsStore: SettingsStore

    let mode: PaletteMode

    // Selection-mode callbacks — palette closes then correction/translation starts.
    var onSelectTone: ((String, TextTransformationAction) -> Void)? = nil

    // Direct-input callback — processing happens inside the palette.
    var onProcessText: ((String, String?, TextTransformationAction) async throws -> String)? = nil

    var onSetDefaultTone: (String) -> Void
    var onClose: () -> Void

    // MARK: State

    @State private var directInputText = ""
    @State private var resultText: String? = nil
    @State private var isProcessing = false
    @State private var errorMessage: String? = nil
    @State private var selectedAction: TextTransformationAction = .correct

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            actionPicker
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            textArea
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            if mode == .directInput, let result = resultText {
                resultArea(result)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            Divider().padding(.bottom, 10)

            defaultToneButton
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            Divider().padding(.bottom, 8)

            toneList
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(width: 400)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(mode == .directInput ? "OverType · Texto directo" : "OverType · Corregir selección")
                    .font(.headline)
                Text("Predeterminado: \(currentDefaultTone.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Action picker

    private var actionPicker: some View {
        Picker("Acción", selection: $selectedAction) {
            Text("Corregir").tag(TextTransformationAction.correct)
            Text("Traducir al inglés").tag(TextTransformationAction.translateToEnglish)
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedAction) {
            resultText = nil
            errorMessage = nil
        }
    }

    // MARK: - Text area

    @ViewBuilder
    private var textArea: some View {
        switch mode {
        case .selection(let text):
            Text(text.count > 200
                 ? String(text.prefix(200)) + "…"
                 : text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )

        case .directInput:
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                if directInputText.isEmpty {
                    Text("Escribe o pega el texto aquí…")
                        .font(.subheadline)
                        .foregroundStyle(Color(nsColor: .placeholderTextColor))
                        .padding(12)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $directInputText)
                    .font(.subheadline)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .frame(minHeight: 80, maxHeight: 140)
                    .padding(8)
                    .onChange(of: directInputText) {
                        resultText = nil
                        errorMessage = nil
                    }
            }
            .frame(minHeight: 96)
        }
    }

    // MARK: - Result area (direct input mode)

    private func resultArea(_ result: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Resultado", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result, forType: .string)
                } label: {
                    Label("Copiar", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            Text(result.count > 300 ? String(result.prefix(300)) + "…" : result)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.green.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.green.opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }

    // MARK: - Default tone button

    private var defaultToneButton: some View {
        Group {
            if mode == .directInput {
                Button {
                    runDirectInput(toneOverride: nil)
                } label: {
                    HStack {
                        if isProcessing {
                            ProgressView().controlSize(.small)
                            Text("Procesando…")
                        } else {
                            Image(systemName: selectedAction == .correct ? "sparkles" : "globe")
                            Text(selectedAction == .correct
                                 ? "Usar tono predeterminado · \(currentDefaultTone.title)"
                                 : "Traducir · \(currentDefaultTone.title)")
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing || directInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                Button {
                    onSelectTone?(currentDefaultTone.id, selectedAction)
                } label: {
                    HStack {
                        Image(systemName: selectedAction == .correct ? "sparkles" : "globe")
                        Text(selectedAction == .correct
                             ? "Usar tono predeterminado · \(currentDefaultTone.title)"
                             : "Traducir · \(currentDefaultTone.title)")
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Tone list

    private var toneList: some View {
        ScrollView {
            VStack(spacing: 6) {
                let tones = ToneOption.allTones(from: settingsStore.settings)
                ForEach(tones) { tone in
                    toneRow(tone)
                }
            }
        }
        .frame(maxHeight: 220)
    }

    private func toneRow(_ tone: ToneOption) -> some View {
        HStack(spacing: 8) {
            Button {
                if mode == .directInput {
                    runDirectInput(toneOverride: tone.id)
                } else {
                    onSelectTone?(tone.id, selectedAction)
                }
            } label: {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            if tone.isCustom {
                                Image(systemName: "person.crop.circle")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(tone.title)
                                .foregroundStyle(.primary)
                        }
                        if tone.id == settingsStore.settings.defaultTone {
                            Text("Tono predeterminado")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                )
            }
            .buttonStyle(.plain)
            .disabled(mode == .directInput && isProcessing)

            // Star to set as default
            Button {
                onSetDefaultTone(tone.id)
            } label: {
                Image(systemName: tone.id == settingsStore.settings.defaultTone ? "star.fill" : "star")
                    .foregroundStyle(tone.id == settingsStore.settings.defaultTone ? .yellow : Color(nsColor: .tertiaryLabelColor))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help("Establecer como tono predeterminado")
        }
    }

    // MARK: - Direct input processing

    private func runDirectInput(toneOverride: String?) {
        let text = directInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let process = onProcessText else { return }

        isProcessing = true
        resultText = nil
        errorMessage = nil

        Task {
            do {
                let result = try await process(text, toneOverride, selectedAction)
                await MainActor.run {
                    self.resultText = result
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isProcessing = false
                }
            }
        }
    }

    // MARK: - Helpers

    private var currentDefaultTone: ToneOption {
        ToneOption.allTones(from: settingsStore.settings)
            .first(where: { $0.id == settingsStore.settings.defaultTone })
            ?? ToneOption(id: settingsStore.settings.defaultTone, title: settingsStore.settings.defaultTone)
    }
}
