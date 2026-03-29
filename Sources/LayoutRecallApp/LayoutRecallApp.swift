import AppKit
import SwiftUI

@main
struct LayoutRecallApp: App {
    @StateObject private var model = AppModel()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(model: model)
        } label: {
            LayoutRecallMenuBarIcon()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}
