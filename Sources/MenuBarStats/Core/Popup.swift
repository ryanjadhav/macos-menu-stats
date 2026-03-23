import AppKit
import SwiftUI

/// Base class for module popup dropdowns.
/// Uses NSPanel with .nonactivatingPanel so clicking the popup never
/// steals focus from the frontmost application.
class BasePopup: NSPanel {
    /// Tracks the currently visible popup so opening a new one closes the old one.
    private static weak var current: BasePopup?

    private var eventMonitor: Any?

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 20),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovable = false
        self.contentView = contentView
    }

    func show(relativeTo button: NSStatusBarButton) {
        // Close whichever other popup is currently open.
        if let previous = BasePopup.current, previous !== self {
            previous.hide()
        }
        BasePopup.current = self

        guard let buttonWindow = button.window else { return }
        let buttonFrame = buttonWindow.convertToScreen(button.frame)

        // Resize panel to fit content
        let contentSize = contentView?.fittingSize ?? NSSize(width: 280, height: 400)
        let height = min(contentSize.height, NSScreen.main.map { $0.visibleFrame.height - 100 } ?? 700)
        let panelWidth: CGFloat = 280
        let x = buttonFrame.minX
        let y = buttonFrame.minY - height

        setFrame(NSRect(x: x, y: y, width: panelWidth, height: height), display: false)
        makeKeyAndOrderFront(nil)
        startEventMonitor()
    }

    func hide() {
        orderOut(nil)
        stopEventMonitor()
        if BasePopup.current === self {
            BasePopup.current = nil
        }
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if isVisible {
            hide()
        } else {
            show(relativeTo: button)
        }
    }

    private func startEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

/// Helper to host a SwiftUI view inside the BasePopup.
final class SwiftUIPopup<Content: View>: BasePopup {
    private var hostingController: NSHostingController<Content>!

    init(rootView: Content) {
        let controller = NSHostingController(rootView: rootView)
        controller.view.frame = NSRect(x: 0, y: 0, width: 280, height: 400)
        super.init(contentView: controller.view)
        self.hostingController = controller
    }

    func updateContent(_ view: Content) {
        hostingController.rootView = view
        let size = hostingController.view.fittingSize
        hostingController.view.frame = NSRect(origin: .zero, size: size)
    }
}
