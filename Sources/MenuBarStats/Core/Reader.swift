import Foundation

/// Generic base class for polling system data on a background queue.
/// Subclasses override `read()` to perform data collection and call
/// `publish(_:)` to deliver results to the main thread.
class BaseReader<T> {
    var updateInterval: TimeInterval = 1.0 {
        didSet { reschedule() }
    }

    /// Called on the main thread when new data is available.
    var callback: ((T) -> Void)?

    private var timer: DispatchSourceTimer?
    private let queue: DispatchQueue

    init(label: String) {
        self.queue = DispatchQueue(
            label: "com.macos-menu-stats.\(label)",
            qos: .utility,
            attributes: [],
            autoreleaseFrequency: .workItem
        )
    }

    deinit {
        stop()
    }

    func start() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: updateInterval, leeway: .milliseconds(50))
        t.setEventHandler { [weak self] in
            self?.read()
        }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    /// Override in subclasses to collect data and call publish().
    func read() {}

    /// Deliver value to callback on main thread.
    func publish(_ value: T) {
        DispatchQueue.main.async { [weak self] in
            self?.callback?(value)
        }
    }

    private func reschedule() {
        guard timer != nil else { return }
        stop()
        start()
    }
}
