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
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button(action: toggleRecording) {
                Text(isRecording ? "Press shortcut" : (binding?.displayString ?? "Record Shortcut"))
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .frame(minWidth: 160, alignment: .center)
            }
            .buttonStyle(ActionButtonStyle(role: isRecording ? .primary : .secondary))

            Button("Clear") {
                onChange(nil)
            }
            .buttonStyle(ActionButtonStyle(role: .quiet))
            .opacity(binding == nil ? 0 : 1)
            .disabled(binding == nil)
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

        return "Key \(event.keyCode)"
    }

    private var specialKeyNames: [UInt16: String] {
        [
            36: "Return",
            48: "Tab",
            49: "Space",
            51: "Delete",
            53: "Esc",
            123: "Left",
            124: "Right",
            125: "Down",
            126: "Up"
        ]
    }
}
