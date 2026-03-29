import SwiftUI

struct SettingsView: View {
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
        Form {
            Section("Restore") {
                Toggle("Enable automatic restore", isOn: autoRestoreBinding)

                Text(model.decisionLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Profiles") {
                ForEach(model.profiles) { profile in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                        Text("Displays: \(profile.displaySet.count)  Threshold: \(profile.settings.confidenceThreshold)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Scaffold status") {
                Text(model.statusLine)
                if !model.lastCommand.isEmpty {
                    Text(model.lastCommand)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 380)
    }
}
