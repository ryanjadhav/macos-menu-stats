import AppKit

/// Permanent gear icon in the menu bar.
/// Clicking it shows a menu to open Settings or quit the app.
final class SettingsStatusItem {
    private let statusItem: NSStatusItem

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "gearshape.fill",
                                   accessibilityDescription: "Settings")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings…",
                                      action: #selector(openSettings),
                                      keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit MenuBar Stats",
                                  action: #selector(NSApplication.terminate(_:)),
                                  keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    @objc private func openSettings() {
        (NSApp.delegate as? AppDelegate)?.openSettings()
    }
}
