import Foundation

public struct DisplayResolution: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public struct DisplayRect: Codable, Equatable, Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct DisplaySnapshot: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var vendorID: Int?
    public var productID: Int?
    public var serialNumber: String?
    public var alphaSerialNumber: String?
    public var persistentID: String?
    public var contextualID: String?
    public var resolution: DisplayResolution
    public var refreshRate: Int?
    public var scale: Double?
    public var bounds: DisplayRect

    public init(
        id: String,
        vendorID: Int? = nil,
        productID: Int? = nil,
        serialNumber: String? = nil,
        alphaSerialNumber: String? = nil,
        persistentID: String? = nil,
        contextualID: String? = nil,
        resolution: DisplayResolution,
        refreshRate: Int? = nil,
        scale: Double? = nil,
        bounds: DisplayRect
    ) {
        self.id = id
        self.vendorID = vendorID
        self.productID = productID
        self.serialNumber = serialNumber
        self.alphaSerialNumber = alphaSerialNumber
        self.persistentID = persistentID
        self.contextualID = contextualID
        self.resolution = resolution
        self.refreshRate = refreshRate
        self.scale = scale
        self.bounds = bounds
    }

    public var preferredMatchKey: String {
        alphaSerialNumber
            ?? serialNumber
            ?? persistentID
            ?? contextualID
            ?? id
    }
}

public extension Array where Element == DisplaySnapshot {
    var fingerprint: String {
        map(\.preferredMatchKey)
            .sorted()
            .joined(separator: "|")
    }
}

public extension DisplaySnapshot {
    static let sampleLeft = DisplaySnapshot(
        id: "left",
        vendorID: 7789,
        productID: 2468,
        serialNumber: "SERIAL-LEFT",
        alphaSerialNumber: "ULTRA-LEFT-001",
        persistentID: "persistent-left",
        contextualID: "usb-c-left",
        resolution: DisplayResolution(width: 2560, height: 1440),
        refreshRate: 60,
        scale: 1.0,
        bounds: DisplayRect(x: 0, y: 0, width: 2560, height: 1440)
    )

    static let sampleRight = DisplaySnapshot(
        id: "right",
        vendorID: 7789,
        productID: 2468,
        serialNumber: "SERIAL-RIGHT",
        alphaSerialNumber: "ULTRA-RIGHT-001",
        persistentID: "persistent-right",
        contextualID: "usb-c-right",
        resolution: DisplayResolution(width: 2560, height: 1440),
        refreshRate: 60,
        scale: 1.0,
        bounds: DisplayRect(x: 2560, y: 0, width: 2560, height: 1440)
    )

    static var developmentDesk: [DisplaySnapshot] {
        [sampleLeft, sampleRight]
    }
}

