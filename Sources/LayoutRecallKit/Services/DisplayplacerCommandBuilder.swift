import Foundation

public struct DisplayplacerCommandBuilder: DisplayCommandBuilding {
    public init() {}

    public func restorePlan(for displays: [DisplaySnapshot]) throws -> GeneratedLayoutPlan {
        guard !displays.isEmpty else {
            throw LayoutRecallRuntimeError.noDisplaysDetected
        }

        let orderedDisplays = displays.sorted(by: DisplaySnapshot.positionComparator)
        let segments = try orderedDisplays.map { display in
            try makeCommandSegment(for: display, originX: display.bounds.x, originY: display.bounds.y)
        }

        return GeneratedLayoutPlan(
            command: "displayplacer " + segments.joined(separator: " "),
            expectedOrigins: orderedDisplays.map { display in
                DisplayOrigin(
                    key: orderedDisplays.uniqueMatchKey(for: display),
                    x: display.bounds.x,
                    y: display.bounds.y
                )
            },
            primaryDisplayKey: orderedDisplays.first.map { orderedDisplays.uniqueMatchKey(for: $0) } ?? "primary"
        )
    }

    public func swapLeftRightPlan(for displays: [DisplaySnapshot]) throws -> GeneratedLayoutPlan {
        let orderedDisplays = displays.sorted(by: DisplaySnapshot.positionComparator)

        guard orderedDisplays.count == 2 else {
            throw LayoutRecallRuntimeError.swapRequiresExactlyTwoDisplays
        }

        let swappedOrigins = [
            DisplayOrigin(
                key: orderedDisplays.uniqueMatchKey(for: orderedDisplays[0]),
                x: orderedDisplays[1].bounds.x,
                y: orderedDisplays[1].bounds.y
            ),
            DisplayOrigin(
                key: orderedDisplays.uniqueMatchKey(for: orderedDisplays[1]),
                x: orderedDisplays[0].bounds.x,
                y: orderedDisplays[0].bounds.y
            )
        ]

        let segments = try [
            makeCommandSegment(for: orderedDisplays[0], originX: swappedOrigins[0].x, originY: swappedOrigins[0].y),
            makeCommandSegment(for: orderedDisplays[1], originX: swappedOrigins[1].x, originY: swappedOrigins[1].y)
        ]

        return GeneratedLayoutPlan(
            command: "displayplacer " + segments.joined(separator: " "),
            expectedOrigins: swappedOrigins,
            primaryDisplayKey: orderedDisplays.uniqueMatchKey(for: orderedDisplays[0])
        )
    }

    private func makeCommandSegment(for display: DisplaySnapshot, originX: Int, originY: Int) throws -> String {
        guard let displayIdentifier = displayplacerIdentifier(for: display) else {
            throw LayoutRecallRuntimeError.invalidDisplayIdentifier(display.id)
        }

        let commandResolution = commandResolution(for: display)
        var parts = [
            "id:\(displayIdentifier)",
            "enabled:true",
            "origin:(\(originX),\(originY))",
            "res:\(commandResolution.width)x\(commandResolution.height)"
        ]

        if let refreshRate = display.refreshRate {
            parts.append("hz:\(refreshRate)")
        }

        if let scale = display.scale {
            parts.append("scaling:\(scale > 1.0 ? "on" : "off")")
        }

        return "'" + parts.joined(separator: " ") + "'"
    }

    private func displayplacerIdentifier(for display: DisplaySnapshot) -> String? {
        if let persistentID = display.persistentID, !persistentID.isEmpty {
            if let uuid = UUID(uuidString: persistentID) {
                return uuid.uuidString
            }

            return persistentID
        }

        if let contextualID = display.contextualID, !contextualID.isEmpty {
            return contextualID
        }

        if let serialNumber = display.serialNumber, !serialNumber.isEmpty {
            return serialNumber.hasPrefix("s") ? serialNumber : "s\(serialNumber)"
        }

        return Int(display.id).map(String.init)
    }

    private func commandResolution(for display: DisplaySnapshot) -> DisplayResolution {
        guard let scale = display.scale, scale > 1 else {
            return display.resolution
        }

        return DisplayResolution(
            width: max(1, Int((Double(display.resolution.width) / scale).rounded())),
            height: max(1, Int((Double(display.resolution.height) / scale).rounded()))
        )
    }
}
