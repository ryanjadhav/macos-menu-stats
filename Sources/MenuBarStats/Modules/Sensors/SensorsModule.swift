import AppKit

final class SensorsModule: SystemModule {
    let id = "sensors"
    let name = "Sensors"
    let symbolName = "thermometer.medium"

    private(set) var isEnabled = false
    private let reader = SensorsReader()
    private var widget: SensorsWidget?

    func enable() {
        guard !isEnabled else { return }
        isEnabled = true
        let w = SensorsWidget()
        widget = w
        reader.updateInterval = Store.shared.double(for: ModuleKeys(id: id).interval, default: 2.0)
        reader.callback = { [weak w] data in
            w?.update(with: data)
        }
        reader.start()
    }

    func disable() {
        guard isEnabled else { return }
        isEnabled = false
        reader.stop()
        widget = nil
    }

    func setUpdateInterval(_ interval: TimeInterval) {
        Store.shared.set(interval, for: ModuleKeys(id: id).interval)
        reader.updateInterval = interval
    }
}
