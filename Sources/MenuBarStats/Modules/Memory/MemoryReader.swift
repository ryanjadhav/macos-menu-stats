import Foundation
import Darwin

// MARK: - Data models

struct MemoryUsage {
    var total: UInt64          // bytes
    var used: UInt64           // active + inactive + wired + compressed
    var wired: UInt64
    var active: UInt64
    var inactive: UInt64
    var compressed: UInt64
    var free: UInt64
    var swapUsed: UInt64
    var swapTotal: UInt64
    var pressureLevel: MemoryPressure
    var usedFraction: Double   // 0.0 – 1.0
    var processes: [MemoryProcess]
}

enum MemoryPressure: Int {
    case normal = 0
    case warning = 2
    case critical = 4

    var label: String {
        switch self {
        case .normal:   return "Normal"
        case .warning:  return "Warning"
        case .critical: return "Critical"
        }
    }

    var color: String {
        switch self {
        case .normal:   return "green"
        case .warning:  return "yellow"
        case .critical: return "red"
        }
    }
}

struct MemoryProcess {
    var pid: Int32
    var name: String
    var residentBytes: UInt64
}

// MARK: - Reader

final class MemoryReader: BaseReader<MemoryUsage> {
    override init(label: String = "memory") {
        super.init(label: label)
    }

    override func read() {
        publish(collectUsage())
    }

    private func collectUsage() -> MemoryUsage {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let pg = UInt64(pageSize)

        let active     = UInt64(stats.active_count)   * pg
        let inactive   = UInt64(stats.inactive_count) * pg
        let wired      = UInt64(stats.wire_count)     * pg
        let compressed = UInt64(stats.compressor_page_count) * pg
        let free       = UInt64(stats.free_count)     * pg

        var totalMem: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalMem, &size, nil, 0)

        let used = active + inactive + wired + compressed
        let usedFraction = totalMem > 0 ? Double(used) / Double(totalMem) : 0

        // Swap usage
        var xsw = xsw_usage()
        var xswSize = MemoryLayout<xsw_usage>.stride
        sysctlbyname("vm.swapusage", &xsw, &xswSize, nil, 0)

        // Memory pressure level
        var pressureInt: Int32 = 0
        var pressureSize = MemoryLayout<Int32>.size
        sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureInt, &pressureSize, nil, 0)
        let pressure = MemoryPressure(rawValue: Int(pressureInt)) ?? .normal

        let processes = result == KERN_SUCCESS ? readTopProcesses() : []

        return MemoryUsage(
            total: totalMem,
            used: used,
            wired: wired,
            active: active,
            inactive: inactive,
            compressed: compressed,
            free: free,
            swapUsed: xsw.xsu_used,
            swapTotal: xsw.xsu_total,
            pressureLevel: pressure,
            usedFraction: usedFraction,
            processes: processes
        )
    }

    private func readTopProcesses() -> [MemoryProcess] {
        var pids = [Int32](repeating: 0, count: 4096)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.size))
        guard count > 0 else { return [] }

        var results: [MemoryProcess] = []
        for i in 0 ..< Int(count) {
            let pid = pids[i]
            guard pid > 0 else { continue }

            var info = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.size)
            let ret = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size)
            guard ret > 0 else { continue }

            let resident = info.pti_resident_size
            guard resident > 1_000_000 else { continue }  // skip tiny processes

            var nameBuffer = [CChar](repeating: 0, count: Int(MAXCOMLEN) + 1)
            proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            let name = String(cString: nameBuffer)
            guard !name.isEmpty else { continue }

            results.append(MemoryProcess(pid: pid, name: name, residentBytes: resident))
        }

        return Array(results.sorted { $0.residentBytes > $1.residentBytes }.prefix(5))
    }
}
