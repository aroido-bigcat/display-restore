import AppKit
import Foundation

public enum ShortcutAction: String, Codable, CaseIterable, Sendable {
    case fixNow
    case saveCurrentLayout
    case swapLeftRight

    public var title: String {
        switch self {
        case .fixNow:
            return "Fix Now"
        case .saveCurrentLayout:
            return "Save Current Layout"
        case .swapLeftRight:
            return "Swap Left / Right"
        }
    }

    public var detail: String {
        switch self {
        case .fixNow:
            return "Run the best matching saved profile immediately."
        case .saveCurrentLayout:
            return "Capture the current display arrangement as a saved profile."
        case .swapLeftRight:
            return "Swap the current two-display layout."
        }
    }
}

public struct ShortcutBinding: Codable, Equatable, Hashable, Sendable {
    public var keyCode: UInt16
    public var modifiersRawValue: UInt
    public var keyDisplay: String

    public init(keyCode: UInt16, modifiersRawValue: UInt, keyDisplay: String) {
        self.keyCode = keyCode
        self.modifiersRawValue = modifiersRawValue
        self.keyDisplay = keyDisplay
    }

    public var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiersRawValue)
            .intersection([.command, .option, .control, .shift])
    }

    public var displayString: String {
        let symbols = [
            modifierFlags.contains(.control) ? "⌃" : nil,
            modifierFlags.contains(.option) ? "⌥" : nil,
            modifierFlags.contains(.shift) ? "⇧" : nil,
            modifierFlags.contains(.command) ? "⌘" : nil
        ]
        .compactMap { $0 }
        .joined()

        return symbols + keyDisplay
    }
}

public struct ShortcutSettings: Codable, Equatable, Sendable {
    public var fixNow: ShortcutBinding?
    public var saveCurrentLayout: ShortcutBinding?
    public var swapLeftRight: ShortcutBinding?

    public init(
        fixNow: ShortcutBinding? = nil,
        saveCurrentLayout: ShortcutBinding? = nil,
        swapLeftRight: ShortcutBinding? = nil
    ) {
        self.fixNow = fixNow
        self.saveCurrentLayout = saveCurrentLayout
        self.swapLeftRight = swapLeftRight
    }

    public subscript(action: ShortcutAction) -> ShortcutBinding? {
        get {
            switch action {
            case .fixNow:
                return fixNow
            case .saveCurrentLayout:
                return saveCurrentLayout
            case .swapLeftRight:
                return swapLeftRight
            }
        }
        set {
            switch action {
            case .fixNow:
                fixNow = newValue
            case .saveCurrentLayout:
                saveCurrentLayout = newValue
            case .swapLeftRight:
                swapLeftRight = newValue
            }
        }
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var launchAtLogin: Bool
    public var shortcuts: ShortcutSettings

    public init(
        launchAtLogin: Bool = false,
        shortcuts: ShortcutSettings = ShortcutSettings()
    ) {
        self.launchAtLogin = launchAtLogin
        self.shortcuts = shortcuts
    }
}
