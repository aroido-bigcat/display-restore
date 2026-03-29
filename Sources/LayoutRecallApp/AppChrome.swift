import AppKit
import LayoutRecallKit
import SwiftUI

struct AppChromeBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .underPageBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.accentColor.opacity(0.14),
                    .clear
                ],
                center: .topLeading,
                startRadius: 24,
                endRadius: 360
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.08),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 16,
                endRadius: 320
            )
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
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
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
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(emphasis ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.06))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(
                                emphasis ? Color.accentColor.opacity(0.22) : Color.white.opacity(0.12),
                                lineWidth: 1
                            )
                    )
            )
    }
}

struct SectionHeading: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
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
                return Color.white.opacity(0.12)
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
            return "Automatic Restore"
        case "manual-fix":
            return "Fix Now"
        case "manual-recovery":
            return "Manual Recovery"
        case "save-profile":
            return "Saved Current Layout"
        case "save-new-profile":
            return "Save New Profile"
        case "swap-left-right":
            return "Swapped Left / Right"
        case "bootstrap-install":
            return "Dependency Setup"
        case "snapshot-read":
            return "Display Read Failed"
        case "idle":
            return "Monitoring"
        default:
            return actionTaken
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
        }
    }

    var outcomeSummary: String {
        switch (executionResult, verificationResult) {
        case (RestoreExecutionOutcome.success.rawValue, RestoreVerificationOutcome.success.rawValue):
            return "Applied and verified"
        case (RestoreExecutionOutcome.success.rawValue, RestoreVerificationOutcome.failed.rawValue):
            return "Applied, verification failed"
        case (RestoreExecutionOutcome.success.rawValue, RestoreVerificationOutcome.unverified.rawValue):
            return "Applied, verification incomplete"
        case (RestoreExecutionOutcome.success.rawValue, RestoreVerificationOutcome.skipped.rawValue):
            switch actionTaken {
            case "save-profile":
                return "Saved successfully"
            case "bootstrap-install":
                return "Dependency ready"
            default:
                return "Completed successfully"
            }
        case (RestoreExecutionOutcome.dependencyMissing.rawValue, _):
            return "displayplacer needed"
        case (RestoreExecutionOutcome.timedOut.rawValue, _):
            return "Timed out"
        case (RestoreExecutionOutcome.failure.rawValue, _):
            return "Action failed"
        case (DependencyInstallOutcome.installed.rawValue, _),
             (DependencyInstallOutcome.alreadyInstalled.rawValue, _):
            return "Dependency ready"
        case (DependencyInstallOutcome.failed.rawValue, _):
            return "Install failed"
        case (RestoreVerificationOutcome.skipped.rawValue, RestoreVerificationOutcome.skipped.rawValue):
            return "Monitoring only"
        default:
            return "Status updated"
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
            .padding(.vertical, role == .quiet ? 0 : 10)
            .frame(maxWidth: role == .primary ? .infinity : nil)
            .foregroundStyle(role == .primary ? Color.white : Color.primary)
            .background(background(isPressed: configuration.isPressed))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }

    @ViewBuilder
    private func background(isPressed: Bool) -> some View {
        switch role {
        case .primary:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentColor.opacity(isPressed ? 0.8 : 0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                )
        case .secondary:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
        case .quiet:
            Color.clear
        }
    }
}
