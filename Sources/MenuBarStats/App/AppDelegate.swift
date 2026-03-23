import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var modules: [any SystemModule] = []
    private var settingsWindowController: SettingsWindowController?
    private var settingsStatusItem: SettingsStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as menu bar only app — no Dock icon
        NSApp.setActivationPolicy(.accessory)

        // Initialize all system modules
        modules = [
            CPUModule(),
            MemoryModule(),
            DiskModule(),
            NetworkModule(),
            SensorsModule(),
            BatteryModule()
        ]

        // Enable each module that is not disabled in settings
        for module in modules {
            let key = "com.macos-menu-stats.\(module.id).enabled"
            let enabled = UserDefaults.standard.object(forKey: key) as? Bool ?? true
            if enabled {
                module.enable()
            }
        }

        // Gear icon — always visible, rightmost item
        settingsStatusItem = SettingsStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        modules.forEach { $0.disable() }
    }

    func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(modules: modules)
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Launch at Login

    func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "register" : "unregister") launch at login: \(error)")
            }
        }
    }

    var launchAtLoginEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
}
