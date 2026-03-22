import AppKit

final class NetworkModule: SystemModule {
    let id = "network"
    let name = "Network"
    let symbolName = "network"

    private(set) var isEnabled = false
    private let reader = NetworkReader()
    private var widget: NetworkWidget?

    func enable() {
        guard !isEnabled else { return }
        isEnabled = true
        let w = NetworkWidget()
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
