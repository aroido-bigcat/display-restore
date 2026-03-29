import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var model: AppModel

    private var autoRestoreBinding: Binding<Bool> {
        Binding(
            get: { model.autoRestoreEnabled },
            set: { newValue in
                model.setAutoRestore(newValue)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Display Restore")
                .font(.headline)

            Text(model.statusLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(model.decisionLine)
                .font(.footnote)

            if !model.lastCommand.isEmpty {
                Text(model.lastCommand)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .textSelection(.enabled)
            }

            Divider()

            Toggle("Auto Restore", isOn: autoRestoreBinding)

            Button("Fix Now", action: model.fixNow)
            Button("Save Current Layout", action: model.saveCurrentLayout)
            Button("Swap Left / Right", action: model.swapLeftRight)

            if !model.profiles.isEmpty {
                Divider()

                Text("Profiles")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(model.profiles.prefix(4)) { profile in
                    Text(profile.name)
                        .font(.footnote)
                }
            }

            Divider()

            Button("Settings") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}
