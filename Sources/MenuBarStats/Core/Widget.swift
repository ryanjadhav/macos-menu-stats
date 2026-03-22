import AppKit
import SwiftUI

/// Display modes available for menu bar widgets.
enum WidgetType: String, CaseIterable {
    case text = "text"
    case barGraph = "bar"
    case lineGraph = "line"
    case ring = "ring"
}

/// Base class for module menu bar widgets.
/// Each module subclasses this, owns an NSStatusItem, and updates it with new data.
class BaseWidget: NSObject {
    let statusItem: NSStatusItem
    let moduleID: String

    init(moduleID: String) {
        self.moduleID = moduleID
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        statusItem.button?.target = self
        statusItem.button?.action = #selector(buttonClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    @objc func buttonClicked() {
        // Subclasses override or modules wire this up.
    }

    /// Replace the status item button content with a SwiftUI view.
    func setView<V: View>(_ view: V, width: CGFloat) {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: 22)
        statusItem.button?.subviews.forEach { $0.removeFromSuperview() }
        statusItem.button?.addSubview(hosting)
        statusItem.length = width
    }

    /// Set plain attributed string for simple text widgets.
    func setText(_ string: NSAttributedString) {
        statusItem.button?.attributedTitle = string
        statusItem.length = NSStatusItem.variableLength
    }

    var widgetType: WidgetType {
        get {
            let raw = UserDefaults.standard.string(forKey: "com.macos-menu-stats.\(moduleID).widgetType") ?? WidgetType.text.rawValue
            return WidgetType(rawValue: raw) ?? .text
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "com.macos-menu-stats.\(moduleID).widgetType")
        }
    }
}
