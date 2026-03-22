import Foundation

/// Lightweight key-value store layered on top of UserDefaults
/// with a per-app suite for clean namespacing.
struct Store {
    static let shared = Store()
    private let defaults: UserDefaults

    private init() {
        defaults = UserDefaults(suiteName: "com.macos-menu-stats") ?? .standard
    }

    func bool(for key: String, default value: Bool = false) -> Bool {
        if defaults.object(forKey: key) == nil { return value }
        return defaults.bool(forKey: key)
    }

    func set(_ value: Bool, for key: String) {
        defaults.set(value, forKey: key)
    }

    func double(for key: String, default value: Double = 0) -> Double {
        if defaults.object(forKey: key) == nil { return value }
        return defaults.double(forKey: key)
    }

    func set(_ value: Double, for key: String) {
        defaults.set(value, forKey: key)
    }

    func string(for key: String, default value: String = "") -> String {
        return defaults.string(forKey: key) ?? value
    }

    func set(_ value: String, for key: String) {
        defaults.set(value, forKey: key)
    }
}

// MARK: - Per-module settings keys

struct ModuleKeys {
    let id: String

    var enabled: String       { "com.macos-menu-stats.\(id).enabled" }
    var interval: String      { "com.macos-menu-stats.\(id).interval" }
    var widgetType: String    { "com.macos-menu-stats.\(id).widgetType" }
    var accentColor: String   { "com.macos-menu-stats.\(id).accentColor" }
}
