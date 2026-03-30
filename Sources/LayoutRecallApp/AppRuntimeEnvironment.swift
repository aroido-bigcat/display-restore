import AppKit
import Foundation
import LayoutRecallKit

@MainActor
enum AppLaunchMode {
    case standard
    case uiAutomationHarness

    static var current: AppLaunchMode {
        RuntimeLaunchArguments.contains("--ui-test-harness")
            || ProcessInfo.processInfo.environment["LAYOUTRECALL_UI_TEST_HARNESS"] == "1"
            ? .uiAutomationHarness
            : .standard
    }

    var activationPolicy: NSApplication.ActivationPolicy {
        switch self {
        case .standard:
            return .accessory
        case .uiAutomationHarness:
            return .regular
        }
    }
}

enum RuntimeLaunchArguments {
    static func contains(_ flag: String) -> Bool {
        CommandLine.arguments.contains(flag)
    }

    static func value(for option: String) -> String? {
        if let exactMatch = CommandLine.arguments.first(where: { $0.hasPrefix("\(option)=") }) {
            return String(exactMatch.dropFirst(option.count + 1))
        }

        guard let index = CommandLine.arguments.firstIndex(of: option),
              CommandLine.arguments.indices.contains(index + 1)
        else {
            return nil
        }

        return CommandLine.arguments[index + 1]
    }
}

@MainActor
func makeAppModel(for launchMode: AppLaunchMode) -> AppModel {
    switch launchMode {
    case .standard:
        return AppModel(
            updateChecker: GitHubReleaseChecker(),
            updateInstaller: GitHubReleaseInstaller(),
            updatePrompt: NSAlertUpdatePrompt()
        )
    case .uiAutomationHarness:
        return AppModel(
            executor: UITestRestoreExecutor(),
            dependencyInstaller: UITestDependencyInstaller(),
            verifier: UITestRestoreVerifier(),
            loginItemManager: UITestLoginItemManager(),
            shortcutManager: UITestShortcutManager(),
            updateChecker: UITestUpdateChecker(),
            updateInstaller: UITestUpdateInstaller(),
            updatePrompt: NoopAppUpdatePrompt()
        )
    }
}

private actor UITestRestoreExecutor: RestoreExecuting {
    func dependencyStatus() async -> RestoreDependencyStatus {
        RestoreDependencyStatus(
            isAvailable: true,
            location: "/opt/homebrew/bin/displayplacer",
            details: L10n.t("restoreExecutor.availableAt", "/opt/homebrew/bin/displayplacer")
        )
    }

    func execute(command: String) async -> RestoreExecutionResult {
        RestoreExecutionResult(
            outcome: .success,
            command: command,
            exitCode: 0,
            stdout: "",
            stderr: "",
            duration: 0.01,
            details: L10n.t("restoreExecutor.success")
        )
    }
}

private actor UITestDependencyInstaller: DependencyInstalling {
    func installDisplayplacerIfNeeded() async -> DependencyInstallResult {
        DependencyInstallResult(
            outcome: .alreadyInstalled,
            dependency: "displayplacer",
            location: "/opt/homebrew/bin/displayplacer",
            details: L10n.t("dependencyInstaller.alreadyInstalled", "/opt/homebrew/bin/displayplacer")
        )
    }
}

private actor UITestRestoreVerifier: RestoreVerifying {
    func verify(expectedOrigins: [DisplayOrigin], using reader: any DisplaySnapshotReading) async -> RestoreVerificationResult {
        RestoreVerificationResult(
            outcome: .success,
            attempts: 1,
            details: L10n.t("verification.success")
        )
    }
}

private actor UITestLoginItemManager: LoginItemManaging {
    private var state: LaunchAtLoginState = .disabled

    func currentState() async -> LaunchAtLoginState {
        state
    }

    func setEnabled(_ enabled: Bool) async throws -> LaunchAtLoginState {
        state = enabled ? .enabled : .disabled
        return state
    }
}

private actor UITestShortcutManager: ShortcutManaging {
    func configure(
        shortcuts: ShortcutSettings,
        handler: @escaping @Sendable (ShortcutAction) -> Void
    ) async throws {}
}

private actor UITestUpdateChecker: AppUpdateChecking {
    func fetchLatestRelease() async throws -> AppRelease? {
        AppRelease(
            tagName: "v9.9.9",
            version: "9.9.9",
            assetName: "LayoutRecall-9.9.9-macos.zip",
            downloadURL: URL(string: "https://example.com/LayoutRecall-9.9.9-macos.zip")!,
            publishedAt: nil,
            releaseNotes: "UI automation test release."
        )
    }
}

private actor UITestUpdateInstaller: AppUpdateInstalling {
    func prepareUpdateInstallation(release: AppRelease, replacing bundleURL: URL) async throws {}
}
