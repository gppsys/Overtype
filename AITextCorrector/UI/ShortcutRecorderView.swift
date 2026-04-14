import AppKit
import Carbon.HIToolbox
import SwiftUI

struct ShortcutRecorderView: View {
    @Binding var shortcut: Shortcut
    let defaultShortcut: Shortcut
    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        HStack(spacing: 6) {
            recorderField
            clearButton
        }
        .onDisappear { stopRecording() }
    }

    // MARK: - Subviews

    private var recorderField: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(nsColor: isRecording ? .selectedControlColor : .controlBackgroundColor).opacity(isRecording ? 0.15 : 1))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(
                            isRecording ? Color.accentColor : Color(nsColor: .separatorColor),
                            lineWidth: isRecording ? 1.5 : 1
                        )
                )

            if isRecording {
                recordingLabel
            } else {
                keyBadgesRow
            }
        }
        .frame(minWidth: 172, minHeight: 30)
        .contentShape(Rectangle())
        .onTapGesture { if !isRecording { startRecording() } }
        .animation(.easeInOut(duration: 0.15), value: isRecording)
    }

    private var recordingLabel: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Color.red)
                .frame(width: 7, height: 7)
                .opacity(pulseOpacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                        pulseOpacity = 0.2
                    }
                }
                .onDisappear { pulseOpacity = 1.0 }
            Text("Presiona el shortcut…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
    }

    private var keyBadgesRow: some View {
        HStack(spacing: 4) {
            ForEach(shortcut.modifierSymbols, id: \.self) { symbol in
                KeyBadge(label: symbol)
            }
            KeyBadge(label: shortcut.keyDisplayName)
        }
        .padding(.horizontal, 10)
    }

    private var clearButton: some View {
        Button {
            shortcut = defaultShortcut
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                .imageScale(.medium)
        }
        .buttonStyle(.plain)
        .help("Restablecer al shortcut por defecto")
    }

    // MARK: - Recording

    private func startRecording() {
        isRecording = true
        NotificationCenter.default.post(name: .shortcutRecordingDidBegin, object: nil)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                self.stopRecording()
                return nil
            }
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !modifiers.isEmpty else { return nil }
            self.shortcut = Shortcut(keyCode: UInt32(event.keyCode), modifiersRawValue: modifiers.rawValue)
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        let wasRecording = isRecording
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        if wasRecording {
            NotificationCenter.default.post(name: .shortcutRecordingDidEnd, object: nil)
        }
    }
}

// MARK: - KeyBadge

private struct KeyBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 0, x: 0, y: 1)
            )
    }
}

// MARK: - Shortcut display helpers

private extension Shortcut {
    var modifierSymbols: [String] {
        let flags = modifierFlags
        var symbols: [String] = []
        if flags.contains(.control) { symbols.append("⌃") }
        if flags.contains(.option)  { symbols.append("⌥") }
        if flags.contains(.shift)   { symbols.append("⇧") }
        if flags.contains(.command) { symbols.append("⌘") }
        return symbols
    }

    var keyDisplayName: String {
        if let mapped = Self.keyNames[keyCode] { return mapped }
        switch keyCode {
        case UInt32(kVK_Space):           return "Space"
        case UInt32(kVK_Return):          return "↩"
        case UInt32(kVK_Tab):             return "⇥"
        case UInt32(kVK_Delete):          return "⌫"
        case UInt32(kVK_ForwardDelete):   return "⌦"
        case UInt32(kVK_LeftArrow):       return "←"
        case UInt32(kVK_RightArrow):      return "→"
        case UInt32(kVK_UpArrow):         return "↑"
        case UInt32(kVK_DownArrow):       return "↓"
        default:                          return "Key \(keyCode)"
        }
    }

    private static let keyNames: [UInt32: String] = {
        let letters: [(Int, String)] = [
            (kVK_ANSI_A,"A"),(kVK_ANSI_B,"B"),(kVK_ANSI_C,"C"),(kVK_ANSI_D,"D"),
            (kVK_ANSI_E,"E"),(kVK_ANSI_F,"F"),(kVK_ANSI_G,"G"),(kVK_ANSI_H,"H"),
            (kVK_ANSI_I,"I"),(kVK_ANSI_J,"J"),(kVK_ANSI_K,"K"),(kVK_ANSI_L,"L"),
            (kVK_ANSI_M,"M"),(kVK_ANSI_N,"N"),(kVK_ANSI_O,"O"),(kVK_ANSI_P,"P"),
            (kVK_ANSI_Q,"Q"),(kVK_ANSI_R,"R"),(kVK_ANSI_S,"S"),(kVK_ANSI_T,"T"),
            (kVK_ANSI_U,"U"),(kVK_ANSI_V,"V"),(kVK_ANSI_W,"W"),(kVK_ANSI_X,"X"),
            (kVK_ANSI_Y,"Y"),(kVK_ANSI_Z,"Z"),
            (kVK_ANSI_0,"0"),(kVK_ANSI_1,"1"),(kVK_ANSI_2,"2"),(kVK_ANSI_3,"3"),
            (kVK_ANSI_4,"4"),(kVK_ANSI_5,"5"),(kVK_ANSI_6,"6"),(kVK_ANSI_7,"7"),
            (kVK_ANSI_8,"8"),(kVK_ANSI_9,"9"),
        ]
        return Dictionary(uniqueKeysWithValues: letters.map { (UInt32($0.0), $0.1) })
    }()
}
