import AppKit

/// Base protocol all system monitoring modules conform to.
protocol SystemModule: AnyObject {
    /// Unique identifier used for settings keys (e.g. "cpu", "memory").
    var id: String { get }
    /// Human-readable display name.
    var name: String { get }
    /// SF Symbol name for the module icon.
    var symbolName: String { get }
    /// Whether this module is currently active.
    var isEnabled: Bool { get }
    /// Start polling and show menu bar item.
    func enable()
    /// Stop polling and remove menu bar item.
    func disable()
    /// Update the polling interval (seconds).
    func setUpdateInterval(_ interval: TimeInterval)
}
