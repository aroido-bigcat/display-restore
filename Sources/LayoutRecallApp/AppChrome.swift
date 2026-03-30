import AppKit
import LayoutRecallKit
import SwiftUI

struct AppChromeBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.08),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(maxHeight: 220, alignment: .top)
        }
        .ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.38), lineWidth: 1)
                )
        )
    }
}

struct StatusPill: View {
    let text: String
    let systemImage: String
    var emphasis = false

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(emphasis ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(
                                emphasis ? Color.accentColor.opacity(0.18) : Color(nsColor: .separatorColor).opacity(0.30),
                                lineWidth: 1
                            )
                    )
            )
    }
}

struct AdaptiveGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8, content: content)
            VStack(alignment: .leading, spacing: 8, content: content)
        }
    }
}

struct SectionHeading: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
    }
}

struct DiagnosticBadge: View {
    enum Tone {
        case positive
        case caution
        case negative
        case neutral

        fileprivate var fill: Color {
            switch self {
            case .positive:
                return .green.opacity(0.14)
            case .caution:
                return .orange.opacity(0.16)
            case .negative:
                return .red.opacity(0.16)
            case .neutral:
                return Color.primary.opacity(0.06)
            }
        }

        fileprivate var stroke: Color {
            switch self {
            case .positive:
                return .green.opacity(0.28)
            case .caution:
                return .orange.opacity(0.28)
            case .negative:
                return .red.opacity(0.28)
            case .neutral:
                return Color(nsColor: .separatorColor).opacity(0.24)
            }
        }
    }

    let text: String
    var tone: Tone = .neutral

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(tone.fill)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(tone.stroke, lineWidth: 1)
                    )
            )
    }
}

struct KeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
    }
}

struct DisplayLayoutPreview: View {
    let displays: [DisplaySnapshot]
    let primaryDisplayKey: String?

    private struct NormalizedDisplay: Identifiable {
        let id: String
        let frame: CGRect
        let isPrimary: Bool
        let index: Int
    }

    var body: some View {
        GeometryReader { proxy in
            let normalizedDisplays = normalizedDisplays(in: proxy.size)

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.66))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color(nsColor: .separatorColor).opacity(0.26), lineWidth: 1)
                    )

                ForEach(normalizedDisplays) { display in
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            display.isPrimary
                                ? Color.accentColor.opacity(0.28)
                                : Color.primary.opacity(0.08)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    display.isPrimary
                                        ? Color.accentColor.opacity(0.56)
                                        : Color(nsColor: .separatorColor).opacity(0.30),
                                    lineWidth: 1
                                )
                        )
                        .frame(width: display.frame.width, height: display.frame.height)
                        .position(
                            x: display.frame.midX,
                            y: display.frame.midY
                        )
                        .overlay(
                            Text("\(display.index)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(display.isPrimary ? Color.white : Color.secondary)
                                .padding(5),
                            alignment: .topLeading
                        )
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func normalizedDisplays(in size: CGSize) -> [NormalizedDisplay] {
        guard !displays.isEmpty else {
            return []
        }

        let minX = displays.map(\.bounds.x).min() ?? 0
        let minY = displays.map(\.bounds.y).min() ?? 0
        let maxX = displays.map { $0.bounds.x + $0.bounds.width }.max() ?? 1
        let maxY = displays.map { $0.bounds.y + $0.bounds.height }.max() ?? 1

        let layoutWidth = max(1, maxX - minX)
        let layoutHeight = max(1, maxY - minY)

        let horizontalPadding: CGFloat = 10
        let verticalPadding: CGFloat = 10
        let availableWidth = max(1, size.width - horizontalPadding * 2)
        let availableHeight = max(1, size.height - verticalPadding * 2)
        let scale = min(
            availableWidth / CGFloat(layoutWidth),
            availableHeight / CGFloat(layoutHeight)
        )
        let contentWidth = CGFloat(layoutWidth) * scale
        let contentHeight = CGFloat(layoutHeight) * scale
        let offsetX = (size.width - contentWidth) / 2
        let offsetY = (size.height - contentHeight) / 2

        return displays.enumerated().map { index, display in
            let x = offsetX + CGFloat(display.bounds.x - minX) * scale
            let y = offsetY + CGFloat(maxY - (display.bounds.y + display.bounds.height)) * scale
            let frame = CGRect(
                x: x,
                y: y,
                width: max(24, CGFloat(display.bounds.width) * scale),
                height: max(18, CGFloat(display.bounds.height) * scale)
            )

            return NormalizedDisplay(
                id: display.id,
                frame: frame,
                isPrimary: primaryDisplayKey.map(display.allMatchKeys.contains) ?? false,
                index: index + 1
            )
        }
    }
}

extension DiagnosticsEntry {
    var confidenceSummary: String? {
        guard let score else {
            return nil
        }

        if score >= 85 {
            return L10n.t("confidence.high")
        }

        if score >= 70 {
            return L10n.t("confidence.review")
        }

        return L10n.t("confidence.low")
    }

    var displayTitle: String {
        switch actionTaken {
        case "auto-restore":
            return L10n.t("diagnostic.title.autoRestore")
        case "manual-fix":
            return L10n.t("diagnostic.title.fixNow")
        case "manual-recovery":
            return L10n.t("diagnostic.title.manualRecovery")
        case "save-profile":
            return L10n.t("diagnostic.title.saveNewProfile")
        case "save-new-profile":
            return L10n.t("diagnostic.title.saveNewProfile")
        case "swap-left-right":
            return L10n.t("diagnostic.title.swappedLeftRight")
        case "bootstrap-install":
            return L10n.t("diagnostic.title.dependencySetup")
        case "snapshot-read":
            return L10n.t("diagnostic.title.displayReadFailed")
        case "idle":
            return L10n.t("diagnostic.title.monitoring")
        default:
            return actionTaken
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
        }
    }

    var outcomeSummary: String {
        switch (executionResult, verificationResult) {
        case (RestoreExecutionOutcome.success.rawValue, RestoreVerificationOutcome.success.rawValue):
            return L10n.t("diagnostic.outcome.appliedVerified")
        case (RestoreExecutionOutcome.success.rawValue, RestoreVerificationOutcome.failed.rawValue):
            return L10n.t("diagnostic.outcome.appliedVerificationFailed")
        case (RestoreExecutionOutcome.success.rawValue, RestoreVerificationOutcome.unverified.rawValue):
            return L10n.t("diagnostic.outcome.appliedVerificationIncomplete")
        case (RestoreExecutionOutcome.success.rawValue, RestoreVerificationOutcome.skipped.rawValue):
            switch actionTaken {
            case "save-profile":
                return L10n.t("diagnostic.outcome.savedSuccessfully")
            case "bootstrap-install":
                return L10n.t("diagnostic.outcome.dependencyReady")
            default:
                return L10n.t("diagnostic.outcome.completedSuccessfully")
            }
        case (RestoreExecutionOutcome.dependencyMissing.rawValue, _):
            return L10n.t("diagnostic.outcome.dependencyNeeded")
        case (RestoreExecutionOutcome.timedOut.rawValue, _):
            return L10n.t("diagnostic.outcome.timedOut")
        case (RestoreExecutionOutcome.failure.rawValue, _):
            return L10n.t("diagnostic.outcome.actionFailed")
        case (DependencyInstallOutcome.installed.rawValue, _),
             (DependencyInstallOutcome.alreadyInstalled.rawValue, _):
            return L10n.t("diagnostic.outcome.dependencyReady")
        case (DependencyInstallOutcome.failed.rawValue, _):
            return L10n.t("diagnostic.outcome.installFailed")
        case (RestoreVerificationOutcome.skipped.rawValue, RestoreVerificationOutcome.skipped.rawValue):
            return L10n.t("diagnostic.outcome.monitoringOnly")
        default:
            return L10n.t("diagnostic.outcome.statusUpdated")
        }
    }

    var outcomeTone: DiagnosticBadge.Tone {
        switch (executionResult, verificationResult) {
        case (RestoreExecutionOutcome.success.rawValue, RestoreVerificationOutcome.success.rawValue),
             (RestoreExecutionOutcome.success.rawValue, RestoreVerificationOutcome.skipped.rawValue),
             (DependencyInstallOutcome.installed.rawValue, _),
             (DependencyInstallOutcome.alreadyInstalled.rawValue, _):
            return .positive
        case (RestoreExecutionOutcome.success.rawValue, RestoreVerificationOutcome.unverified.rawValue),
             (RestoreExecutionOutcome.dependencyMissing.rawValue, _),
             (RestoreExecutionOutcome.timedOut.rawValue, _):
            return .caution
        case (RestoreExecutionOutcome.failure.rawValue, _),
             (DependencyInstallOutcome.failed.rawValue, _),
             (RestoreExecutionOutcome.success.rawValue, RestoreVerificationOutcome.failed.rawValue):
            return .negative
        default:
            return .neutral
        }
    }
}

struct ActionButtonStyle: ButtonStyle {
    enum Role {
        case primary
        case secondary
        case quiet
    }

    let role: Role

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, role == .quiet ? 0 : 14)
            .padding(.vertical, role == .quiet ? 0 : 9)
            .frame(maxWidth: role == .primary ? .infinity : nil)
            .foregroundStyle(role == .primary ? Color.white : Color.primary)
            .background(background(isPressed: configuration.isPressed))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }

    @ViewBuilder
    private func background(isPressed: Bool) -> some View {
        switch role {
        case .primary:
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(isPressed ? 0.82 : 0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
        case .secondary:
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(isPressed ? 0.92 : 0.80))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.34), lineWidth: 1)
                )
        case .quiet:
            Color.clear
        }
    }
}

struct InlineActionButtonStyle: ButtonStyle {
    var accent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(accent ? Color.accentColor : Color.secondary)
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.66 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
