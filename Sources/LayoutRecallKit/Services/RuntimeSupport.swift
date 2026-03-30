import Foundation

public protocol ProfileStoring: Sendable {
    func loadProfiles() async throws -> [DisplayProfile]
    func saveProfiles(_ profiles: [DisplayProfile]) async throws
}

public protocol DisplaySnapshotReading: Sendable {
    func currentDisplays() async throws -> [DisplaySnapshot]
}

public struct GeneratedLayoutPlan: Equatable, Sendable {
    public var command: String
    public var expectedOrigins: [DisplayOrigin]
    public var primaryDisplayKey: String

    public init(command: String, expectedOrigins: [DisplayOrigin], primaryDisplayKey: String) {
        self.command = command
        self.expectedOrigins = expectedOrigins
        self.primaryDisplayKey = primaryDisplayKey
    }
}

public protocol DisplayCommandBuilding: Sendable {
    func restorePlan(for displays: [DisplaySnapshot]) throws -> GeneratedLayoutPlan
    func swapLeftRightPlan(for displays: [DisplaySnapshot]) throws -> GeneratedLayoutPlan
}

public struct RestoreDependencyStatus: Equatable, Sendable {
    public var isAvailable: Bool
    public var location: String?
    public var details: String

    public init(isAvailable: Bool, location: String? = nil, details: String) {
        self.isAvailable = isAvailable
        self.location = location
        self.details = details
    }
}

public enum RestoreExecutionOutcome: String, Codable, Equatable, Sendable {
    case success
    case failure
    case timedOut
    case dependencyMissing
}

public struct RestoreExecutionResult: Equatable, Sendable {
    public var outcome: RestoreExecutionOutcome
    public var command: String
    public var exitCode: Int32?
    public var stdout: String
    public var stderr: String
    public var duration: TimeInterval
    public var details: String

    public init(
        outcome: RestoreExecutionOutcome,
        command: String,
        exitCode: Int32? = nil,
        stdout: String = "",
        stderr: String = "",
        duration: TimeInterval = 0,
        details: String
    ) {
        self.outcome = outcome
        self.command = command
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.duration = duration
        self.details = details
    }
}

public protocol RestoreExecuting: Sendable {
    func dependencyStatus() async -> RestoreDependencyStatus
    func execute(command: String) async -> RestoreExecutionResult
}

public enum DependencyInstallOutcome: String, Codable, Equatable, Sendable {
    case installed
    case alreadyInstalled
    case failed
}

public struct DependencyInstallResult: Equatable, Sendable {
    public var outcome: DependencyInstallOutcome
    public var dependency: String
    public var location: String?
    public var details: String

    public init(
        outcome: DependencyInstallOutcome,
        dependency: String,
        location: String? = nil,
        details: String
    ) {
        self.outcome = outcome
        self.dependency = dependency
        self.location = location
        self.details = details
    }
}

public protocol DependencyInstalling: Sendable {
    func installDisplayplacerIfNeeded() async -> DependencyInstallResult
}

public enum RestoreVerificationOutcome: String, Codable, Equatable, Sendable {
    case success
    case failed
    case unverified
    case skipped
}

public struct RestoreVerificationResult: Equatable, Sendable {
    public var outcome: RestoreVerificationOutcome
    public var attempts: Int
    public var details: String

    public init(outcome: RestoreVerificationOutcome, attempts: Int, details: String) {
        self.outcome = outcome
        self.attempts = attempts
        self.details = details
    }

    public static let skipped = RestoreVerificationResult(
        outcome: .skipped,
        attempts: 0,
        details: L10n.t("verify.skipped")
    )
}

public protocol RestoreVerifying: Sendable {
    func verify(expectedOrigins: [DisplayOrigin], using reader: any DisplaySnapshotReading) async -> RestoreVerificationResult
}

public protocol DiagnosticsStoring: Sendable {
    func recentEntries() async throws -> [DiagnosticsEntry]
    func append(_ entry: DiagnosticsEntry) async throws
}

public protocol AppSettingsStoring: Sendable {
    func loadSettings() async throws -> AppSettings
    func saveSettings(_ settings: AppSettings) async throws
}

public enum LaunchAtLoginState: Equatable, Sendable {
    case enabled
    case disabled
    case requiresApproval
    case unsupported(String)

    public var description: String {
        switch self {
        case .enabled:
            return L10n.t("launchAtLogin.enabled")
        case .disabled:
            return L10n.t("launchAtLogin.disabled")
        case .requiresApproval:
            return L10n.t("launchAtLogin.requiresApproval")
        case .unsupported(let details):
            return details
        }
    }
}

public protocol LoginItemManaging: Sendable {
    func currentState() async -> LaunchAtLoginState
    func setEnabled(_ enabled: Bool) async throws -> LaunchAtLoginState
}

public enum LayoutRecallRuntimeError: LocalizedError, Sendable {
    case noDisplaysDetected
    case swapRequiresExactlyTwoDisplays
    case invalidDisplayIdentifier(String)
    case noCompatibleProfile
    case emptyCommand

    public var errorDescription: String? {
        switch self {
        case .noDisplaysDetected:
            return L10n.t("runtime.noDisplays")
        case .swapRequiresExactlyTwoDisplays:
            return L10n.t("runtime.swapRequiresTwo")
        case .invalidDisplayIdentifier(let identifier):
            return L10n.t("runtime.invalidDisplayIdentifier", identifier)
        case .noCompatibleProfile:
            return L10n.t("runtime.noCompatibleProfile")
        case .emptyCommand:
            return L10n.t("runtime.emptyCommand")
        }
    }
}

enum LayoutRecallStorage {
    static func baseDirectory() -> URL {
        if let overrideRoot = commandLineValue(for: "--storage-root"),
           !overrideRoot.isEmpty
        {
            return URL(fileURLWithPath: overrideRoot, isDirectory: true)
        }

        if let overrideRoot = ProcessInfo.processInfo.environment["LAYOUTRECALL_STORAGE_ROOT"],
           !overrideRoot.isEmpty
        {
            return URL(fileURLWithPath: overrideRoot, isDirectory: true)
        }

        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        return baseDirectory.appendingPathComponent("LayoutRecall", isDirectory: true)
    }

    static func fileURL(named name: String) -> URL {
        baseDirectory().appendingPathComponent(name, isDirectory: false)
    }

    private static func commandLineValue(for option: String) -> String? {
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
