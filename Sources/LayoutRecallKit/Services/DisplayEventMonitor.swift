import Foundation
import AppKit
import CoreGraphics

public enum DisplayEventType: String, Codable, Sendable {
    case reconfigured
    case wake
    case manual
    case restoreVerification
}

public struct DisplayEvent: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var timestamp: Date
    public var type: DisplayEventType
    public var details: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), type: DisplayEventType, details: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.details = details
    }
}

public protocol DisplayEventMonitoring: AnyObject {
    func start(handler: @escaping @Sendable (DisplayEvent) -> Void)
    func stop()
}

public final class NoopDisplayEventMonitor: DisplayEventMonitoring {
    private var handler: (@Sendable (DisplayEvent) -> Void)?

    public init() {}

    public func start(handler: @escaping @Sendable (DisplayEvent) -> Void) {
        self.handler = handler
    }

    public func stop() {
        handler = nil
    }
}

private let displayRestoreReconfigurationCallback: CGDisplayReconfigurationCallBack = { _, _, userInfo in
    guard let userInfo else {
        return
    }

    let monitor = Unmanaged<CGDisplayEventMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    monitor.emit(type: .reconfigured, details: "CoreGraphics display reconfiguration callback fired.")
}

public final class CGDisplayEventMonitor: DisplayEventMonitoring, @unchecked Sendable {
    private var handler: (@Sendable (DisplayEvent) -> Void)?
    private var wakeObserver: NSObjectProtocol?
    private var running = false

    public init() {}

    public func start(handler: @escaping @Sendable (DisplayEvent) -> Void) {
        guard !running else {
            self.handler = handler
            return
        }

        self.handler = handler
        running = true

        CGDisplayRegisterReconfigurationCallback(
            displayRestoreReconfigurationCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.emit(type: .wake, details: "macOS wake notification fired.")
        }
    }

    public func stop() {
        guard running else {
            return
        }

        CGDisplayRemoveReconfigurationCallback(
            displayRestoreReconfigurationCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )

        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }

        wakeObserver = nil
        handler = nil
        running = false
    }

    deinit {
        stop()
    }

    fileprivate func emit(type: DisplayEventType, details: String) {
        handler?(DisplayEvent(type: type, details: details))
    }
}
