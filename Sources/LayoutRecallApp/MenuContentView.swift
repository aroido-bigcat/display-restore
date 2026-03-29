import AppKit
import LayoutRecallKit
import SwiftUI

private struct MenuActionItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let action: () -> Void
}

struct MenuContentView: View {
    @ObservedObject var model: AppModel

    private var primaryAction: MenuActionItem? {
        switch model.menuPrimaryState {
        case .noProfiles:
            return MenuActionItem(
                id: "save",
                title: L10n.t("action.save"),
                systemImage: "square.and.arrow.down",
                action: model.saveCurrentLayout
            )
        case .dependencyMissing:
            return MenuActionItem(
                id: "install",
                title: model.installationInProgress
                    ? L10n.t("dependency.installingDisplayplacer")
                    : L10n.t("dependency.installDisplayplacer"),
                systemImage: model.installationInProgress ? "hourglass" : "arrow.down.circle.fill",
                action: model.installDisplayplacer
            )
        case .manualRecovery:
            return MenuActionItem(
                id: "fix-now",
                title: L10n.t("action.fixNow"),
                systemImage: "bolt.fill",
                action: model.fixNow
            )
        case .healthy:
            return nil
        }
    }

    private var secondaryActions: [MenuActionItem] {
        var actions: [MenuActionItem] = []

        if model.menuPrimaryState == .healthy {
            actions.append(
                MenuActionItem(
                    id: "fix-now-secondary",
                    title: L10n.t("action.fixNow"),
                    systemImage: "bolt.fill",
                    action: model.fixNow
                )
            )
        }

        actions.append(
            MenuActionItem(
                id: "save-secondary",
                title: L10n.t("action.save"),
                systemImage: "square.and.arrow.down",
                action: model.saveCurrentLayout
            )
        )
        actions.append(
            MenuActionItem(
                id: "swap-secondary",
                title: L10n.t("action.swap"),
                systemImage: "arrow.left.and.right.square",
                action: model.swapLeftRight
            )
        )

        return actions
    }

    var body: some View {
        ZStack {
            AppChromeBackground()

            VStack(alignment: .leading, spacing: 14) {
                header
                statusBlock

                if let primaryAction {
                    Button(action: primaryAction.action) {
                        Label(primaryAction.title, systemImage: primaryAction.systemImage)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ActionButtonStyle(role: .primary))
                    .disabled(model.installationInProgress)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ],
                    spacing: 8
                ) {
                    ForEach(secondaryActions) { action in
                        Button(action: action.action) {
                            Label(action.title, systemImage: action.systemImage)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ActionButtonStyle(role: .secondary))
                    }
                }

                Divider()

                footer
            }
            .padding(16)
        }
        .frame(width: 320)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(L10n.t("app.name"))
                .font(.headline.weight(.semibold))

            Spacer(minLength: 0)

            LayoutRecallHeaderIcon(dimension: 28)
        }
    }

    private var statusBlock: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.menuStatusTitle)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(model.menuStatusSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(model.menuMetadataLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Label(L10n.t("action.settings"), systemImage: "gearshape")
            }
            .buttonStyle(ActionButtonStyle(role: .quiet))

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label(L10n.t("action.quit"), systemImage: "xmark.circle")
            }
            .buttonStyle(ActionButtonStyle(role: .quiet))
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
    }
}
