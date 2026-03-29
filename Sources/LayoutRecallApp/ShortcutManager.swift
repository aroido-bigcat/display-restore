import AppKit
import Carbon
import LayoutRecallKit
import Foundation

protocol ShortcutManaging: Sendable {
    func configure(
        shortcuts: ShortcutSettings,
        handler: @escaping @Sendable (ShortcutAction) -> Void
    ) async throws
}

enum ShortcutManagerError: LocalizedError {
    case registrationFailed(ShortcutAction, OSStatus)

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let action, let status):
            return "Failed to register the \(action.title) shortcut. OSStatus: \(status)"
        }
    }
}

final class GlobalHotKeyManager: ShortcutManaging, @unchecked Sendable {
    private let signature = fourCharCode("DRHK")
    private var handler: (@Sendable (ShortcutAction) -> Void)?
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRefs: [ShortcutAction: EventHotKeyRef] = [:]

    init() {
        installEventHandlerIfNeeded()
    }

    deinit {
        unregisterAll()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func configure(
        shortcuts: ShortcutSettings,
        handler: @escaping @Sendable (ShortcutAction) -> Void
    ) async throws {
        self.handler = handler
        installEventHandlerIfNeeded()
        unregisterAll()

        for action in ShortcutAction.allCases {
            guard let binding = shortcuts[action] else {
                continue
            }

            try register(binding, for: action)
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else {
                    return noErr
                }

                let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handle(event: event)
            },
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )
    }

    private func register(_ binding: ShortcutBinding, for action: ShortcutAction) throws {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: action.hotKeyID)
        let status = RegisterEventHotKey(
            UInt32(binding.keyCode),
            carbonFlags(from: binding.modifierFlags),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let hotKeyRef else {
            throw ShortcutManagerError.registrationFailed(action, status)
        }

        hotKeyRefs[action] = hotKeyRef
    }

    private func unregisterAll() {
        for (_, hotKeyRef) in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }

        hotKeyRefs.removeAll()
    }

    private func handle(event: EventRef?) -> OSStatus {
        guard let event else {
            return noErr
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr, hotKeyID.signature == signature else {
            return status
        }

        guard let action = ShortcutAction(hotKeyID: hotKeyID.id) else {
            return noErr
        }

        handler?(action)
        return noErr
    }

    private func carbonFlags(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0

        if flags.contains(.command) {
            result |= UInt32(cmdKey)
        }
        if flags.contains(.option) {
            result |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            result |= UInt32(controlKey)
        }
        if flags.contains(.shift) {
            result |= UInt32(shiftKey)
        }

        return result
    }
}

private func fourCharCode(_ value: String) -> OSType {
    value.utf8.reduce(0) { ($0 << 8) + OSType($1) }
}

private extension ShortcutAction {
    var hotKeyID: UInt32 {
        switch self {
        case .fixNow:
            return 1
        case .saveCurrentLayout:
            return 2
        case .swapLeftRight:
            return 3
        }
    }

    init?(hotKeyID: UInt32) {
        switch hotKeyID {
        case 1:
            self = .fixNow
        case 2:
            self = .saveCurrentLayout
        case 3:
            self = .swapLeftRight
        default:
            return nil
        }
    }
}
