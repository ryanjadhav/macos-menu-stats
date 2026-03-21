import AppKit

final class CPUModule: SystemModule {
    let id = "cpu"
    let name = "CPU"
    let symbolName = "cpu"

    private(set) var isEnabled = false
    private let reader = CPUReader()
    private var widget: CPUWidget?

    func enable() {
        guard !isEnabled else { return }
        isEnabled = true
        let w = CPUWidget()
        widget = w
        reader.updateInterval = Store.shared.double(for: ModuleKeys(id: id).interval, default: 1.0)
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
