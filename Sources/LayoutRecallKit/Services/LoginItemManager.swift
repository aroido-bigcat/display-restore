import Foundation
import ServiceManagement

public final class AppLoginItemManager: LoginItemManaging, @unchecked Sendable {
    public init() {}

    public func currentState() async -> LaunchAtLoginState {
        guard #available(macOS 13, *) else {
            return .unsupported(L10n.t("launchAtLogin.unsupported.macos"))
        }

        return map(service.status)
    }

    public func setEnabled(_ enabled: Bool) async throws -> LaunchAtLoginState {
        guard #available(macOS 13, *) else {
            return .unsupported(L10n.t("launchAtLogin.unsupported.macos"))
        }

        if enabled {
            try service.register()
        } else {
            try await service.unregister()
        }

        return map(service.status)
    }

    @available(macOS 13, *)
    private var service: SMAppService {
        SMAppService.mainApp
    }

    @available(macOS 13, *)
    private func map(_ status: SMAppService.Status) -> LaunchAtLoginState {
        switch status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unsupported(L10n.t("launchAtLogin.unsupported.bundle"))
        @unknown default:
            return .unsupported(L10n.t("launchAtLogin.unsupported.unknown"))
        }
    }
}
