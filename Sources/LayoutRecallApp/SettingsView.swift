import LayoutRecallKit
import SwiftUI

private struct PaneHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title2.weight(.semibold))

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct FormHint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var selectedPane: SettingsPane = .restore

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
        HStack(spacing: 0) {
            List(SettingsPane.allCases, selection: $selectedPane) { pane in
                Label(pane.title, systemImage: pane.systemImage)
                    .tag(pane)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .underPageBackgroundColor))
            .frame(width: 220)

            Divider()

            detailPane(for: selectedPane)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 760, height: 560)
    }

    @ViewBuilder
    private func detailPane(for pane: SettingsPane) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PaneHeader(title: pane.title, subtitle: pane.subtitle)

                switch pane {
                case .restore:
                    restorePane
                case .profiles:
                    profilesPane
                case .shortcuts:
                    shortcutsPane
                case .diagnostics:
                    diagnosticsPane
                case .general:
                    generalPane
                }
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }

    private var restorePane: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.menuStatusTitle)
                        .font(.headline)

                    Text(model.menuStatusSubtitle)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(model.menuMetadataLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label(L10n.t("settings.currentState"), systemImage: "checkmark.circle")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(L10n.t("toggle.enableAutomaticRestore"), isOn: autoRestoreBinding)
                        .toggleStyle(.switch)

                    FormHint(text: model.dependencyLine)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label(L10n.t("menu.automaticRestore"), systemImage: "sparkles")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    if !model.dependencyAvailable || model.installationInProgress {
                        Button(action: model.installDisplayplacer) {
                            Label(
                                model.installationInProgress
                                    ? L10n.t("dependency.installingDisplayplacer")
                                    : L10n.t("dependency.installDisplayplacer"),
                                systemImage: model.installationInProgress ? "hourglass" : "arrow.down.circle.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ActionButtonStyle(role: .secondary))
                        .disabled(model.installationInProgress)
                    }

                    HStack(spacing: 10) {
                        Button(action: model.fixNow) {
                            Label(L10n.t("action.fixNow"), systemImage: "bolt.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ActionButtonStyle(role: .primary))

                        Button(action: model.saveCurrentLayout) {
                            Label(L10n.t("action.save"), systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ActionButtonStyle(role: .secondary))
                    }

                    Button(action: model.swapLeftRight) {
                        Label(L10n.t("action.swap"), systemImage: "arrow.left.and.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ActionButtonStyle(role: .secondary))
                }
            } label: {
                Label(L10n.t("settings.actions"), systemImage: "bolt.badge.clock")
            }
        }
    }

    private var profilesPane: some View {
        GroupBox {
            if model.profiles.isEmpty {
                Text(L10n.t("profiles.empty"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(model.profiles.enumerated()), id: \.element.id) { index, profile in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label(profile.name, systemImage: "display")
                                        .font(.headline)

                                    Text(L10n.t("settings.profileDisplaySummary", profile.displaySet.count))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 6) {
                                    Text(L10n.t("settings.profileAutoRestore"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Toggle(
                                        "",
                                        isOn: Binding(
                                            get: { profile.settings.autoRestore },
                                            set: { model.setProfileAutoRestore(profile.id, to: $0) }
                                        )
                                    )
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                }
                            }

                            TextField(
                                L10n.t("field.profileName"),
                                text: Binding(
                                    get: { profile.name },
                                    set: { model.renameProfile(profile.id, to: $0) }
                                )
                            )
                            .textFieldStyle(.roundedBorder)

                            HStack(alignment: .center, spacing: 12) {
                                Stepper(
                                    value: Binding(
                                        get: { profile.settings.confidenceThreshold },
                                        set: { model.setConfidenceThreshold(profile.id, to: $0) }
                                    ),
                                    in: 50...100
                                ) {
                                    Text(L10n.confidenceThreshold(profile.settings.confidenceThreshold))
                                }

                                Spacer()

                                if profile.settings.autoRestore {
                                    Text(L10n.t("restore.automatic"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(L10n.t("restore.manualOnly"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if index < model.profiles.count - 1 {
                            Divider()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } label: {
            Label(L10n.t("section.profiles"), systemImage: "square.stack.3d.up.fill")
        }
    }

    private var shortcutsPane: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(ShortcutAction.allCases, id: \.rawValue) { action in
                    ShortcutRecorderRow(
                        title: action.title,
                        detail: action.detail,
                        binding: model.shortcutBinding(for: action),
                        onChange: { model.setShortcut($0, for: action) }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(L10n.t("section.shortcuts"), systemImage: "command")
        }
    }

    private var diagnosticsPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text(model.dependencyLine)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(model.statusLine)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !model.lastCommand.isEmpty {
                        DisclosureGroup(L10n.t("section.lastCommand")) {
                            ScrollView(.horizontal) {
                                Text(model.lastCommand)
                                    .font(.system(size: 11, design: .monospaced))
                                    .textSelection(.enabled)
                                    .padding(.top, 6)
                            }
                            .frame(height: 44)
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label(L10n.t("settings.runtimeInfo"), systemImage: "terminal")
            }

            GroupBox {
                if model.diagnostics.isEmpty {
                    Text(L10n.t("diagnostics.empty"))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(model.diagnostics.prefix(5).enumerated()), id: \.element.id) { index, entry in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(entry.displayTitle)
                                        .font(.headline)

                                    if let score = entry.score {
                                        Text(L10n.score(score))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
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

                            if index < min(model.diagnostics.count, 5) - 1 {
                                Divider()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } label: {
                Label(L10n.t("section.diagnostics"), systemImage: "stethoscope")
            }
        }
    }

    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(L10n.t("toggle.launchAtLogin"), isOn: launchAtLoginBinding)
                        .toggleStyle(.switch)

                    FormHint(text: model.loginItemLine)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label(L10n.t("toggle.launchAtLogin"), systemImage: "switch.2")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.appVersionDescription)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label(L10n.t("settings.appInfo"), systemImage: "info.circle")
            }
        }
    }
}
