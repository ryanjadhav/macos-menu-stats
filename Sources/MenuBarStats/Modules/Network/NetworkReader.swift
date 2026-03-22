import Foundation
import Darwin

// MARK: - Data models

struct NetworkStats {
    var downloadBytesPerSec: Double
    var uploadBytesPerSec: Double
    var downloadHistory: [Double]   // 0.0–1.0 normalised
    var uploadHistory: [Double]
    var interfaces: [NetworkInterface]
    var publicIP: String?           // nil = unknown/fetching
    var processes: [NetworkProcess]
}

struct NetworkInterface {
    var name: String         // e.g. "en0"
    var displayName: String  // e.g. "Wi-Fi"
    var localIPv4: String?
    var localIPv6: String?
    var isActive: Bool
    var type: InterfaceType

    enum InterfaceType: String {
        case wifi    = "Wi-Fi"
        case ethernet = "Ethernet"
        case loopback = "Loopback"
        case other   = "Other"
    }
}

struct NetworkProcess {
    var pid: Int32
    var name: String
    var rxBytes: UInt64
    var txBytes: UInt64
}

// MARK: - Reader

final class NetworkReader: BaseReader<NetworkStats> {
    private var prevBytes: [String: (rx: UInt64, tx: UInt64)] = [:]
    private var prevTimestamp = Date()
    private var downloadHistory: [Double] = []
    private var uploadHistory:   [Double] = []
    private var publicIP: String? = nil
    private var publicIPLastFetch: Date = .distantPast
    private let publicIPCacheDuration: TimeInterval = 300  // 5 minutes

    override init(label: String = "network") {
        super.init(label: label)
    }

    override func read() {
        // Refresh public IP in background if stale
        if Date().timeIntervalSince(publicIPLastFetch) > publicIPCacheDuration {
            fetchPublicIP()
        }
        publish(collectStats())
    }

    private func collectStats() -> NetworkStats {
        let (download, upload, interfaces) = readInterfaceStats()
        let processes = readTopProcesses()

        return NetworkStats(
            downloadBytesPerSec: download,
            uploadBytesPerSec: upload,
            downloadHistory: downloadHistory,
            uploadHistory: uploadHistory,
            interfaces: interfaces,
            publicIP: publicIP,
            processes: processes
        )
    }

    // MARK: - Interface stats via getifaddrs

    private func readInterfaceStats() -> (download: Double, upload: Double, interfaces: [NetworkInterface]) {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let head = addrs else {
            return (0, 0, [])
        }
        defer { freeifaddrs(addrs) }

        var rxTotal: UInt64 = 0
        var txTotal: UInt64 = 0
        var ifaceMap: [String: NetworkInterface] = [:]
        var currentBytes: [String: (rx: UInt64, tx: UInt64)] = [:]

        var ptr = head
        while true {
            let flags = Int32(ptr.pointee.ifa_flags)
            let name = String(cString: ptr.pointee.ifa_name)

            // Skip loopback and down interfaces for bandwidth total
            let isUp       = (flags & IFF_UP) != 0
            let isRunning  = (flags & IFF_RUNNING) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            if let data = ptr.pointee.ifa_data {
                let ifdata = data.assumingMemoryBound(to: if_data.self).pointee
                let rx = UInt64(ifdata.ifi_ibytes)
                let tx = UInt64(ifdata.ifi_obytes)
                currentBytes[name] = (rx, tx)

                if isUp && isRunning && !isLoopback {
                    rxTotal += rx
                    txTotal += tx
                }
            }

            // Gather IP addresses
            if ptr.pointee.ifa_addr != nil {
                let family = Int32(ptr.pointee.ifa_addr.pointee.sa_family)
                if family == AF_INET {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(ptr.pointee.ifa_addr, socklen_t(ptr.pointee.ifa_addr.pointee.sa_len),
                                &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                    let ip = String(cString: host)
                    if var iface = ifaceMap[name] {
                        iface.localIPv4 = ip
                        ifaceMap[name] = iface
                    } else {
                        let type = interfaceType(name: name)
                        ifaceMap[name] = NetworkInterface(
                            name: name,
                            displayName: displayName(for: name),
                            localIPv4: ip,
                            localIPv6: nil,
                            isActive: isUp && isRunning,
                            type: type
                        )
                    }
                } else if family == AF_INET6 {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(ptr.pointee.ifa_addr, socklen_t(ptr.pointee.ifa_addr.pointee.sa_len),
                                &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                    let ip = String(cString: host)
                    if var iface = ifaceMap[name] {
                        iface.localIPv6 = ip
                        ifaceMap[name] = iface
                    } else {
                        let type = interfaceType(name: name)
                        ifaceMap[name] = NetworkInterface(
                            name: name,
                            displayName: displayName(for: name),
                            localIPv4: nil,
                            localIPv6: ip,
                            isActive: isUp && isRunning,
                            type: type
                        )
                    }
                }
            }

            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }

        // Calculate deltas
        let now = Date()
        let elapsed = max(now.timeIntervalSince(prevTimestamp), 0.1)
        var downloadRate: Double = 0
        var uploadRate:   Double = 0

        for (name, curr) in currentBytes {
            if let prev = prevBytes[name] {
                let rxDelta = curr.rx > prev.rx ? curr.rx - prev.rx : 0
                let txDelta = curr.tx > prev.tx ? curr.tx - prev.tx : 0
                downloadRate += Double(rxDelta)
                uploadRate   += Double(txDelta)
            }
        }
        downloadRate /= elapsed
        uploadRate   /= elapsed

        prevBytes     = currentBytes
        prevTimestamp = now

        // Normalise history to a reasonable max (10 MB/s)
        let maxRate: Double = 10 * 1024 * 1024
        downloadHistory.append(min(downloadRate / maxRate, 1.0))
        uploadHistory.append(  min(uploadRate   / maxRate, 1.0))
        if downloadHistory.count > 60 { downloadHistory.removeFirst() }
        if uploadHistory.count   > 60 { uploadHistory.removeFirst() }

        let interfaces = Array(ifaceMap.values
            .filter { $0.isActive && $0.type != .loopback }
            .sorted { $0.name < $1.name })

        return (downloadRate, uploadRate, interfaces)
    }

    // MARK: - Interface type helpers

    private func interfaceType(name: String) -> NetworkInterface.InterfaceType {
        if name.hasPrefix("en") { return .wifi }        // en0 = Wi-Fi, en1 = Ethernet typically
        if name.hasPrefix("eth") { return .ethernet }
        if name.hasPrefix("lo") { return .loopback }
        return .other
    }

    private func displayName(for name: String) -> String {
        if name.hasPrefix("en0") { return "Wi-Fi" }
        if name.hasPrefix("en1") { return "Ethernet" }
        if name.hasPrefix("lo") { return "Loopback" }
        return name
    }

    // MARK: - Public IP fetch (async, updates stored value)

    private func fetchPublicIP() {
        publicIPLastFetch = Date()  // prevent re-entry before response arrives
        Task {
            guard let url = URL(string: "https://api.ipify.org") else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let ip = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async { [weak self] in
                        self?.publicIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.publicIP = nil
                }
            }
        }
    }

    // MARK: - Top processes by network I/O

    private func readTopProcesses() -> [NetworkProcess] {
        var pids = [Int32](repeating: 0, count: 4096)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.size))
        guard count > 0 else { return [] }

        var results: [NetworkProcess] = []
        for i in 0 ..< Int(count) {
            let pid = pids[i]
            guard pid > 0 else { continue }

            var ruinfo = rusage_info_v4()
            let ret: Int32 = withUnsafeMutablePointer(to: &ruinfo) { ptr in
                var voidPtr: rusage_info_t? = UnsafeMutableRawPointer(ptr)
                return proc_pid_rusage(pid, RUSAGE_INFO_V4, &voidPtr)
            }
            guard ret == 0 else { continue }

            // Use cumulative disk I/O as a proxy for process activity
            // (per-process network I/O is not available via public APIs)
            let rx = ruinfo.ri_diskio_bytesread
            let tx = ruinfo.ri_diskio_byteswritten
            guard rx + tx > 0 else { continue }

            var nameBuffer = [CChar](repeating: 0, count: Int(MAXCOMLEN) + 1)
            proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            let name = String(cString: nameBuffer)
            guard !name.isEmpty else { continue }

            results.append(NetworkProcess(pid: pid, name: name, rxBytes: rx, txBytes: tx))
        }

        return Array(results.sorted { ($0.rxBytes + $0.txBytes) > ($1.rxBytes + $1.txBytes) }.prefix(5))
    }
}
