import AppKit
import LayoutRecallKit
import SwiftUI

@MainActor
private final class SettingsWindowCoordinator: ObservableObject {
    private var windowController: NSWindowController?

    func show(model: AppModel) {
        let windowController = windowController ?? makeWindowController(model: model)
        self.windowController = windowController

        if let hostingController = windowController.contentViewController as? NSHostingController<SettingsView> {
            hostingController.rootView = SettingsView(model: model)
        }

        NSApp.activate(ignoringOtherApps: true)
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindowController(model: AppModel) -> NSWindowController {
        let hostingController = NSHostingController(rootView: SettingsView(model: model))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.t("action.settings")
        window.contentViewController = hostingController
        window.minSize = NSSize(width: 760, height: 560)
        window.isReleasedWhenClosed = false
        window.center()

        return NSWindowController(window: window)
    }
}

@MainActor
private final class MenuHarnessWindowCoordinator: ObservableObject {
    private var windowController: NSWindowController?

    func show(model: AppModel, openSettings: @escaping () -> Void) {
        let windowController = windowController ?? makeWindowController(model: model, openSettings: openSettings)
        self.windowController = windowController

        if let hostingController = windowController.contentViewController as? NSHostingController<MenuContentView> {
            hostingController.rootView = MenuContentView(model: model, openSettings: openSettings)
        }

        NSApp.activate(ignoringOtherApps: true)
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindowController(model: AppModel, openSettings: @escaping () -> Void) -> NSWindowController {
        let hostingController = NSHostingController(rootView: MenuContentView(model: model, openSettings: openSettings))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 336, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LayoutRecall Menu"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.center()

        return NSWindowController(window: window)
    }
}

private struct LayoutRecallCommands: Commands {
    let openSettings: () -> Void

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(L10n.t("action.settingsMenu")) {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

@main
struct LayoutRecallApp: App {
    @StateObject private var model: AppModel
    @StateObject private var settingsWindowCoordinator: SettingsWindowCoordinator
    @StateObject private var menuHarnessWindowCoordinator: MenuHarnessWindowCoordinator
    private let launchMode: AppLaunchMode

    init() {
        let launchMode = AppLaunchMode.current
        NSApplication.shared.setActivationPolicy(launchMode.activationPolicy)
        let settingsWindowCoordinator = SettingsWindowCoordinator()
        let menuHarnessWindowCoordinator = MenuHarnessWindowCoordinator()
        let model = makeAppModel(for: launchMode)

        self.launchMode = launchMode
        _settingsWindowCoordinator = StateObject(wrappedValue: settingsWindowCoordinator)
        _menuHarnessWindowCoordinator = StateObject(wrappedValue: menuHarnessWindowCoordinator)
        _model = StateObject(wrappedValue: model)

        let openSettingsOnLaunch = RuntimeLaunchArguments.contains("--open-settings-on-launch")
            || ProcessInfo.processInfo.environment["LAYOUTRECALL_OPEN_SETTINGS_ON_LAUNCH"] == "1"

        if openSettingsOnLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                settingsWindowCoordinator.show(model: model)
            }
        }

        if launchMode == .uiAutomationHarness {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                menuHarnessWindowCoordinator.show(
                    model: model,
                    openSettings: { settingsWindowCoordinator.show(model: model) }
                )
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(
                model: model,
                openSettings: { settingsWindowCoordinator.show(model: model) }
            )
        } label: {
            LayoutRecallMenuBarIcon()
        }
        .menuBarExtraStyle(.window)
        .commands {
            LayoutRecallCommands(
                openSettings: { settingsWindowCoordinator.show(model: model) }
            )
        }
    }
}
