import AppKit
import LayoutRecallKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var model: AppModel
    let openSettings: () -> Void
    @State private var hasAnimatedIn = false

    var body: some View {
        ZStack {
            AppChromeBackground()

            VStack(alignment: .leading, spacing: 12) {
                header
                statusBlock

                if let action = model.menuPrimaryAction {
                    primaryActionButton(for: action)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if !model.menuQuickActions.isEmpty {
                    quickActions
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Divider()
                    .padding(.top, 2)

                footer
            }
            .padding(14)
            .offset(y: hasAnimatedIn ? 0 : 6)
            .opacity(hasAnimatedIn ? 1 : 0.96)
        }
        .frame(width: 316)
        .onAppear {
            guard !hasAnimatedIn else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                hasAnimatedIn = true
            }
        }
        .animation(.spring(response: 0.30, dampingFraction: 0.84), value: model.menuTransitionKey)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(L10n.t("app.name"))
                .font(.headline.weight(.semibold))

            Spacer(minLength: 0)

            LayoutRecallSymbol(
                tone: model.menuPrimaryState == .healthy ? .brand : .template,
                lineWidth: 1.9
            )
                .frame(width: 20, height: 20)
                .opacity(model.menuPrimaryState == .healthy ? 0.94 : 0.76)
        }
    }

    private var statusBlock: some View {
        GlassCard(padding: 14) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 12) {
                    statusBanner

                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.menuStatusTitle)
                            .font(.title3.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(model.menuStatusSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    evidencePills

                    if let profile = model.referenceProfile {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.t("menu.reference"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(profile.name)
                                    .font(.subheadline.weight(.semibold))
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(model.menuMetadataLine)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                if let recentActivityLine = model.menuRecentActivityLine {
                                    Text(recentActivityLine)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            Spacer(minLength: 0)

                            DisplayLayoutPreview(
                                displays: model.referenceDisplays,
                                primaryDisplayKey: model.referencePrimaryDisplayKey
                            )
                            .frame(width: 92, height: 62)
                        }
                    } else {
                        Text(model.menuMetadataLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .id(model.menuTransitionKey)
                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
            }
        }
    }

    private var statusBanner: some View {
        HStack(alignment: .center, spacing: 10) {
            StatusPill(
                text: model.menuStatePresentation.badgeText,
                systemImage: model.menuStatePresentation.systemImage,
                emphasis: model.menuPrimaryState != .healthy
            )

            Spacer(minLength: 0)

            if let recentActivityLine = model.menuRecentActivityLine {
                Text(recentActivityLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var evidencePills: some View {
        AdaptiveGroup {
            StatusPill(
                text: model.autoRestoreBadgeText,
                systemImage: "sparkles",
                emphasis: model.autoRestoreEnabled
            )

            StatusPill(
                text: model.dependencyBadgeText,
                systemImage: model.installationInProgress ? "hourglass" : "shippingbox",
                emphasis: model.dependencyAvailable
            )

            StatusPill(
                text: model.displayBadgeText,
                systemImage: "rectangle.on.rectangle"
            )

            if let confidenceBadgeText = model.confidenceBadgeText {
                StatusPill(
                    text: confidenceBadgeText,
                    systemImage: "checkmark.seal",
                    emphasis: model.confidencePresentation == .high
                )
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: 14) {
            ForEach(model.menuQuickActions) { action in
                Button(action: { model.perform(action) }) {
                    Label(title(for: action), systemImage: systemImage(for: action))
                }
                .buttonStyle(InlineActionButtonStyle(accent: false))
                .disabled(isDisabled(action))
                .accessibilityIdentifier("menu.quick.\(action.rawValue)")
            }

            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        HStack {
            Button(L10n.t("action.settings")) {
                openSettings()
            }
            .buttonStyle(InlineActionButtonStyle())
            .accessibilityIdentifier("menu.footer.settings")

            Spacer()

            Button(L10n.t("action.quit")) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(InlineActionButtonStyle())
            .accessibilityIdentifier("menu.footer.quit")
        }
    }

    @ViewBuilder
    private func primaryActionButton(for action: SurfaceAction) -> some View {
        Button(action: { model.perform(action) }) {
            Label(model.menuTitle(for: action), systemImage: systemImage(for: action))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(ActionButtonStyle(role: .primary))
        .disabled(isDisabled(action))
        .accessibilityIdentifier("menu.primary.\(action.rawValue)")
    }

    private func title(for action: SurfaceAction) -> String {
        switch action {
        case .installDependency:
            return model.installationInProgress
                ? L10n.t("dependency.installingDisplayplacer")
                : action.title
        case .fixNow, .saveNewProfile:
            return action == .saveNewProfile ? model.menuTitle(for: action) : action.title
        }
    }

    private func systemImage(for action: SurfaceAction) -> String {
        switch action {
        case .installDependency:
            return model.installationInProgress ? "hourglass" : action.systemImage
        case .fixNow, .saveNewProfile:
            return action.systemImage
        }
    }

    private func isDisabled(_ action: SurfaceAction) -> Bool {
        switch action {
        case .installDependency:
            return model.installationInProgress
        case .fixNow, .saveNewProfile:
            return false
        }
    }
}
