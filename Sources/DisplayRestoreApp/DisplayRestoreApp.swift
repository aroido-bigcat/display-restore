import AppKit
import SwiftUI

@main
struct DisplayRestoreApp: App {
    @StateObject private var model = AppModel()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("Display Restore", systemImage: "display.2") {
            MenuContentView(model: model)
        }

        Settings {
            SettingsView(model: model)
        }
    }
}

