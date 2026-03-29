import Foundation
import ServiceManagement

public final class AppLoginItemManager: LoginItemManaging, @unchecked Sendable {
    public init() {}

    public func currentState() async -> LaunchAtLoginState {
        guard #available(macOS 13, *) else {
            return .unsupported("Launch at login requires macOS 13 or newer.")
        }

        return map(service.status)
    }

    public func setEnabled(_ enabled: Bool) async throws -> LaunchAtLoginState {
        guard #available(macOS 13, *) else {
            return .unsupported("Launch at login requires macOS 13 or newer.")
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
            return .unsupported("Launch at login is unavailable for this app bundle.")
        @unknown default:
            return .unsupported("Launch at login returned an unknown system status.")
        }
    }
}
