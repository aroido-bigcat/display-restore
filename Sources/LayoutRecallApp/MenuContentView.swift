import AppKit
import LayoutRecallKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var model: AppModel
    @State private var showsLastCommand = false

    private var autoRestoreBinding: Binding<Bool> {
        Binding(
            get: { model.autoRestoreEnabled },
            set: { newValue in
                model.setAutoRestore(newValue)
            }
        )
    }

    private var profileSummary: String {
        "\(model.profiles.count) Profile" + (model.profiles.count == 1 ? "" : "s")
    }

    private var autoRestoreSummary: String {
        model.autoRestoreEnabled ? "Automatic" : "Manual"
    }

    private var dependencySummary: String {
        if model.installationInProgress {
            return "Installing"
        }

        return model.dependencyAvailable ? "Ready" : "Install"
    }

    private var latestProfile: DisplayProfile? {
        model.profiles.first
    }

    var body: some View {
        ZStack {
            AppChromeBackground()

            VStack(alignment: .leading, spacing: 10) {
                header
                badges
                actionsCard

                if latestProfile != nil || model.diagnostics.first != nil {
                    statusCard
                }

                if !model.lastCommand.isEmpty {
                    commandCard
                }

                footer
            }
            .padding(16)
        }
        .frame(width: 356)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LayoutRecall")
                    .font(.title3.weight(.semibold))

                Text(model.statusLine)
                    .font(.subheadline)

                Text(model.decisionLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "display.2")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var badges: some View {
        HStack(spacing: 8) {
            StatusPill(text: autoRestoreSummary, systemImage: model.autoRestoreEnabled ? "bolt.fill" : "hand.raised.fill", emphasis: model.autoRestoreEnabled)
            StatusPill(text: profileSummary, systemImage: "square.stack.3d.up")
            StatusPill(text: dependencySummary, systemImage: model.dependencyAvailable ? "checkmark.circle.fill" : "arrow.down.circle", emphasis: model.installationInProgress)
        }
    }

    private var actionsCard: some View {
        GlassCard(padding: 14) {
            SectionHeading(title: "Actions", systemImage: "wand.and.stars")

            HStack(spacing: 12) {
                Text("Automatic restore")
                    .font(.subheadline)
                Spacer()
                Toggle("", isOn: autoRestoreBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            Text(model.dependencyLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !model.dependencyAvailable {
                Button(action: model.installDisplayplacer) {
                    Label(
                        model.installationInProgress ? "Installing displayplacer" : "Install displayplacer",
                        systemImage: model.installationInProgress ? "hourglass" : "arrow.down.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ActionButtonStyle(role: .secondary))
                .disabled(model.installationInProgress)
            }

            Button(action: model.fixNow) {
                Label("Fix Now", systemImage: "bolt.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ActionButtonStyle(role: .primary))

            HStack(spacing: 10) {
                Button(action: model.saveCurrentLayout) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(ActionButtonStyle(role: .secondary))

                Button(action: model.swapLeftRight) {
                    Label("Swap", systemImage: "arrow.left.and.right.square")
                }
                .buttonStyle(ActionButtonStyle(role: .secondary))
            }
        }
    }

    private var statusCard: some View {
        GlassCard(padding: 14) {
            SectionHeading(title: "Status", systemImage: "checkmark.seal")

            if let latestProfile {
                VStack(alignment: .leading, spacing: 8) {
                    KeyValueRow(label: "Profile", value: latestProfile.name)
                    KeyValueRow(label: "Displays", value: "\(latestProfile.displaySet.count)")
                    KeyValueRow(label: "Threshold", value: "\(latestProfile.settings.confidenceThreshold)")
                }
            }

            if let latestDiagnostic = model.diagnostics.first {
                if latestProfile != nil {
                    Divider()
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(latestDiagnostic.displayTitle)
                            .font(.subheadline.weight(.semibold))

                        if let score = latestDiagnostic.score {
                            DiagnosticBadge(text: "Score \(score)")
                        }
                    }

                    DiagnosticBadge(
                        text: latestDiagnostic.outcomeSummary,
                        tone: latestDiagnostic.outcomeTone
                    )

                    Text(latestDiagnostic.details)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var commandCard: some View {
        GlassCard(padding: 14) {
            DisclosureGroup("Last Command", isExpanded: $showsLastCommand) {
                ScrollView(.horizontal) {
                    Text(model.lastCommand)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(.top, 6)
                }
                .scrollIndicators(.visible)
                .frame(height: 44)
            }
            .font(.caption.weight(.semibold))
        }
    }

    private var footer: some View {
        HStack {
            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(ActionButtonStyle(role: .quiet))

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "xmark.circle")
            }
            .buttonStyle(ActionButtonStyle(role: .quiet))
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
    }
}
