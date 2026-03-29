import Foundation

public enum DisplayEventType: String, Codable, Sendable {
    case reconfigured
    case wake
    case manual
}

public struct DisplayEvent: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var timestamp: Date
    public var type: DisplayEventType

    public init(id: UUID = UUID(), timestamp: Date = Date(), type: DisplayEventType) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
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

