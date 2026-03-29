import ColorSync
import CoreGraphics
import Foundation

public enum DisplaySnapshotReaderError: LocalizedError, Sendable {
    case onlineDisplayListFailed(CGError)

    public var errorDescription: String? {
        switch self {
        case .onlineDisplayListFailed(let error):
            return "Failed to query online displays: \(error.rawValue)"
        }
    }
}

public struct DisplaySnapshotReader: DisplaySnapshotReading {
    public init() {}

    public func currentDisplays() async throws -> [DisplaySnapshot] {
        let maxDisplays: UInt32 = 16
        var activeDisplays = Array(repeating: CGDirectDisplayID(), count: Int(maxDisplays))
        var displayCount: UInt32 = 0
        let error = CGGetOnlineDisplayList(maxDisplays, &activeDisplays, &displayCount)

        guard error == .success else {
            throw DisplaySnapshotReaderError.onlineDisplayListFailed(error)
        }

        return activeDisplays
            .prefix(Int(displayCount))
            .map(makeSnapshot(displayID:))
            .sorted(by: DisplaySnapshot.positionComparator)
    }

    private func makeSnapshot(displayID: CGDirectDisplayID) -> DisplaySnapshot {
        let displayMode = CGDisplayCopyDisplayMode(displayID)
        let pixelWidth = displayMode.map(\.pixelWidth) ?? Int(CGDisplayPixelsWide(displayID))
        let pixelHeight = displayMode.map(\.pixelHeight) ?? Int(CGDisplayPixelsHigh(displayID))
        let pointWidth = displayMode.map(\.width) ?? pixelWidth
        let scale = pointWidth > 0 ? Double(pixelWidth) / Double(pointWidth) : nil
        let refreshRate = displayMode.map(\.refreshRate).flatMap { $0 > 0 ? Int($0.rounded()) : nil }
        let bounds = CGDisplayBounds(displayID)
        let serialNumber = nonZeroString(CGDisplaySerialNumber(displayID))
        let displayUUID = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue()
        let persistentID = displayUUID.map { uuid in
            (CFUUIDCreateString(nil, uuid) as String).lowercased()
        }

        return DisplaySnapshot(
            id: String(displayID),
            vendorID: nonZeroInt(CGDisplayVendorNumber(displayID)),
            productID: nonZeroInt(CGDisplayModelNumber(displayID)),
            serialNumber: serialNumber,
            alphaSerialNumber: nil,
            persistentID: persistentID,
            contextualID: nonZeroString(CGDisplayUnitNumber(displayID)),
            resolution: DisplayResolution(width: pixelWidth, height: pixelHeight),
            refreshRate: refreshRate,
            scale: scale,
            bounds: DisplayRect(
                x: Int(bounds.origin.x.rounded()),
                y: Int(bounds.origin.y.rounded()),
                width: Int(bounds.size.width.rounded()),
                height: Int(bounds.size.height.rounded())
            )
        )
    }

    private func nonZeroInt<T: BinaryInteger>(_ value: T) -> Int? {
        value == 0 ? nil : Int(value)
    }

    private func nonZeroString<T: BinaryInteger>(_ value: T) -> String? {
        value == 0 ? nil : String(value)
    }
}
