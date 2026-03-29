import LayoutRecallKit
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

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.launchAtLoginEnabled },
            set: { newValue in
                model.setLaunchAtLogin(newValue)
            }
        )
    }

    var body: some View {
        ZStack {
            AppChromeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    overviewSection
                    shortcutsCard
                    profilesSection
                    diagnosticsCard
                    runtimeCard
                }
                .padding(24)
                .frame(maxWidth: 760, alignment: .leading)
            }
        }
        .frame(width: 680, height: 640)
    }

    private var overviewSection: some View {
        HStack(alignment: .top, spacing: 18) {
            generalCard
                .frame(width: 220, alignment: .leading)

            restoreCard
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LayoutRecall")
                    .font(.largeTitle.weight(.semibold))

                Text("Keep saved monitor layouts ready, restore conservatively, and fall back to manual recovery when confidence is low.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "display.2")
                .font(.system(size: 24, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var generalCard: some View {
        GlassCard {
            SectionHeading(title: "General", systemImage: "switch.2")

            Toggle("Launch at login", isOn: launchAtLoginBinding)
                .toggleStyle(.switch)

            Text(model.loginItemLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var restoreCard: some View {
        GlassCard {
            SectionHeading(title: "Restore", systemImage: "sparkles.rectangle.stack")

            HStack(spacing: 8) {
                StatusPill(text: model.autoRestoreEnabled ? "Automatic" : "Manual only", systemImage: model.autoRestoreEnabled ? "bolt.fill" : "hand.raised.fill", emphasis: model.autoRestoreEnabled)
                StatusPill(text: "\(model.profiles.count) profile" + (model.profiles.count == 1 ? "" : "s"), systemImage: "square.stack.3d.up")
                StatusPill(
                    text: model.installationInProgress ? "Installing" : (model.dependencyAvailable ? "Ready" : "Install"),
                    systemImage: model.dependencyAvailable ? "checkmark.circle.fill" : "arrow.down.circle",
                    emphasis: model.installationInProgress
                )
            }

            Toggle("Enable automatic restore", isOn: autoRestoreBinding)
                .toggleStyle(.switch)

            Text(model.decisionLine)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

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
                }
                .buttonStyle(ActionButtonStyle(role: .secondary))
                .disabled(model.installationInProgress)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.profiles.isEmpty {
                GlassCard {
                    SectionHeading(title: "Profiles", systemImage: "square.stack.3d.up.fill")
                    Text("Save the current layout to create your first profile.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(model.profiles) { profile in
                    GlassCard {
                        SectionHeading(title: profile.name, systemImage: "display")

                        TextField(
                            "Profile name",
                            text: Binding(
                                get: { profile.name },
                                set: { model.renameProfile(profile.id, to: $0) }
                            )
                        )
                        .textFieldStyle(.roundedBorder)

                        Stepper(
                            value: Binding(
                                get: { profile.settings.confidenceThreshold },
                                set: { model.setConfidenceThreshold(profile.id, to: $0) }
                            ),
                            in: 50...100
                        ) {
                            Text("Confidence threshold: \(profile.settings.confidenceThreshold)")
                        }

                        Text("\(profile.displaySet.count) displays in this layout")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var shortcutsCard: some View {
        GlassCard {
            SectionHeading(title: "Shortcuts", systemImage: "command")

            VStack(alignment: .leading, spacing: 14) {
                ForEach(ShortcutAction.allCases, id: \.rawValue) { action in
                    ShortcutRecorderRow(
                        title: action.title,
                        detail: action.detail,
                        binding: model.shortcutBinding(for: action),
                        onChange: { model.setShortcut($0, for: action) }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var diagnosticsCard: some View {
        GlassCard {
            SectionHeading(title: "Diagnostics", systemImage: "stethoscope")

            if model.diagnostics.isEmpty {
                Text("No diagnostics have been recorded yet.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(model.diagnostics.prefix(8).enumerated()), id: \.element.id) { index, entry in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(entry.displayTitle)
                                    .font(.subheadline.weight(.semibold))

                                if let score = entry.score {
                                    DiagnosticBadge(text: "Score \(score)")
                                }
                            }

                            HStack(spacing: 8) {
                                DiagnosticBadge(
                                    text: entry.outcomeSummary,
                                    tone: entry.outcomeTone
                                )

                                if let profileName = entry.profileName {
                                    DiagnosticBadge(text: profileName)
                                }
                            }

                            Text(entry.details)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if index < min(model.diagnostics.count, 8) - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var runtimeCard: some View {
        GlassCard {
            SectionHeading(title: "Runtime", systemImage: "terminal")

            Text(model.statusLine)
                .font(.body)

            if !model.lastCommand.isEmpty {
                ScrollView(.horizontal) {
                    Text(model.lastCommand)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.visible)
                .frame(height: 58)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
