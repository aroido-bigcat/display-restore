import Foundation

public struct DisplaySet: Codable, Equatable, Sendable {
    public var count: Int
    public var fingerprint: String
    public var displays: [DisplaySnapshot]

    public init(count: Int, fingerprint: String, displays: [DisplaySnapshot]) {
        self.count = count
        self.fingerprint = fingerprint
        self.displays = displays
    }
}

public struct DisplayOrigin: Codable, Equatable, Sendable {
    public var key: String
    public var x: Int
    public var y: Int

    public init(key: String, x: Int, y: Int) {
        self.key = key
        self.x = x
        self.y = y
    }
}

public struct LayoutEngineCommand: Codable, Equatable, Sendable {
    public var type: String
    public var command: String

    public init(type: String, command: String) {
        self.type = type
        self.command = command
    }
}

public struct LayoutDefinition: Codable, Equatable, Sendable {
    public var primaryDisplayKey: String
    public var expectedOrigins: [DisplayOrigin]
    public var engine: LayoutEngineCommand

    public init(primaryDisplayKey: String, expectedOrigins: [DisplayOrigin], engine: LayoutEngineCommand) {
        self.primaryDisplayKey = primaryDisplayKey
        self.expectedOrigins = expectedOrigins
        self.engine = engine
    }
}

public struct ProfileSettings: Codable, Equatable, Sendable {
    public var autoRestore: Bool
    public var confidenceThreshold: Int

    public init(autoRestore: Bool = true, confidenceThreshold: Int = 70) {
        self.autoRestore = autoRestore
        self.confidenceThreshold = confidenceThreshold
    }
}

public struct DisplayProfile: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var displaySet: DisplaySet
    public var layout: LayoutDefinition
    public var settings: ProfileSettings

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        displaySet: DisplaySet,
        layout: LayoutDefinition,
        settings: ProfileSettings = ProfileSettings()
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.displaySet = displaySet
        self.layout = layout
        self.settings = settings
    }
}

public extension DisplayProfile {
    static func draft(name: String, displays: [DisplaySnapshot], command: String) -> DisplayProfile {
        let origins = displays.map {
            DisplayOrigin(key: $0.preferredMatchKey, x: $0.bounds.x, y: $0.bounds.y)
        }

        return DisplayProfile(
            name: name,
            displaySet: DisplaySet(
                count: displays.count,
                fingerprint: displays.fingerprint,
                displays: displays
            ),
            layout: LayoutDefinition(
                primaryDisplayKey: displays.first?.preferredMatchKey ?? "primary",
                expectedOrigins: origins,
                engine: LayoutEngineCommand(type: "displayplacer", command: command)
            )
        )
    }

    static let officeDock = DisplayProfile.draft(
        name: "Office Dock",
        displays: DisplaySnapshot.developmentDesk,
        command: "displayplacer 'id:ULTRA-LEFT-001 origin:(0,0) res:2560x1440 hz:60' 'id:ULTRA-RIGHT-001 origin:(2560,0) res:2560x1440 hz:60'"
    )
}

