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

extension DiagnosticsEntry {
    var displayTitle: String {
        switch actionTaken {
        case "auto-restore":
            return L10n.t("diagnostic.title.autoRestore")
        case "manual-fix":
            return L10n.t("diagnostic.title.fixNow")
        case "manual-recovery":
            return L10n.t("diagnostic.title.manualRecovery")
        case "save-profile":
            return L10n.t("diagnostic.title.savedCurrentLayout")
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
