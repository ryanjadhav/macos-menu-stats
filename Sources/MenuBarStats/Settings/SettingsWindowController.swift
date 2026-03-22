import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    private let modules: [any SystemModule]

    init(modules: [any SystemModule]) {
        self.modules = modules

        let settingsView = SettingsView(modules: modules)
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "MenuBar Stats Settings"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 560, height: 420))
        window.minSize = NSSize(width: 520, height: 380)
        window.center()

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}
