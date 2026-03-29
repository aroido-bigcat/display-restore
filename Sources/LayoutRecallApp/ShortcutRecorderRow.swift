import AppKit
import LayoutRecallKit
import SwiftUI

struct ShortcutRecorderRow: View {
    let title: String
    let detail: String
    let binding: ShortcutBinding?
    let onChange: (ShortcutBinding?) -> Void

    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                details
                Spacer(minLength: 12)
                controls
            }

            VStack(alignment: .leading, spacing: 10) {
                details
                controls
            }
        }
        .onChange(of: isRecording) { newValue in
            if newValue {
                installMonitor()
            } else {
                removeMonitor()
            }
        }
        .onDisappear {
            removeMonitor()
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button(action: toggleRecording) {
                Text(isRecording ? L10n.t("shortcut.press") : (binding?.displayString ?? L10n.t("shortcut.record")))
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .frame(minWidth: 140, alignment: .center)
            }
            .buttonStyle(ActionButtonStyle(role: isRecording ? .primary : .secondary))

            Button(L10n.t("action.clear")) {
                onChange(nil)
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .opacity(binding == nil ? 0 : 1)
            .disabled(binding == nil)
        }
    }

    private func toggleRecording() {
        isRecording.toggle()
    }

    private func installMonitor() {
        removeMonitor()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isRecording else {
                return event
            }

            if event.keyCode == 53 {
                isRecording = false
                return nil
            }

            let binding = ShortcutBinding(
                keyCode: event.keyCode,
                modifiersRawValue: event.modifierFlags.intersection([.command, .option, .control, .shift]).rawValue,
                keyDisplay: keyDisplay(for: event)
            )
            onChange(binding)
            isRecording = false
            return nil
        }
    }

    private func removeMonitor() {
        guard let eventMonitor else {
            return
        }

        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
    }

    private func keyDisplay(for event: NSEvent) -> String {
        if let mappedKey = specialKeyNames[event.keyCode] {
            return mappedKey
        }

        if let characters = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines),
           !characters.isEmpty {
            return characters.uppercased()
        }

        return L10n.t("shortcut.key.default", Int(event.keyCode))
    }

    private var specialKeyNames: [UInt16: String] {
        [
            36: L10n.t("shortcut.key.return"),
            48: L10n.t("shortcut.key.tab"),
            49: L10n.t("shortcut.key.space"),
            51: L10n.t("shortcut.key.delete"),
            53: L10n.t("shortcut.key.esc"),
            123: L10n.t("shortcut.key.left"),
            124: L10n.t("shortcut.key.right"),
            125: L10n.t("shortcut.key.down"),
            126: L10n.t("shortcut.key.up")
        ]
    }
}
