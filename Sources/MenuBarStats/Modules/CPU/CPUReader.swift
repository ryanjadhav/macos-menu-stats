import Foundation
import Darwin

// MARK: - Data models

struct CPUUsage {
    var total: Double          // 0.0 – 1.0 overall usage
    var user: Double
    var system: Double
    var idle: Double
    var cores: [CoreUsage]     // per-core breakdown
    var loadAvg: (Double, Double, Double)  // 1m, 5m, 15m
    var uptime: TimeInterval
    var processes: [CPUProcess]
    var eCoreCount: Int        // Apple Silicon efficiency cores (0 on Intel)
    var pCoreCount: Int        // Apple Silicon performance cores (0 on Intel)
}

struct CoreUsage {
    var user: Double
    var system: Double
    var idle: Double
    var total: Double { user + system }
    var isEfficiency: Bool     // true = E-core on Apple Silicon
}

struct CPUProcess {
    var pid: Int32
    var name: String
    var cpuUsage: Double  // 0.0 – 100.0
}

// MARK: - Reader

final class CPUReader: BaseReader<CPUUsage> {
    // Previous tick's cpu_info for delta calculation
    private var prevCpuInfo: [Int32] = []
    private var prevNumCPUs: Int = 0

    // Apple Silicon core topology
    private let eCoreCount: Int
    private let pCoreCount: Int

    override init(label: String = "cpu") {
        // Read core topology once at init
        var eCount: Int = 0
        var pCount: Int = 0
        var size = MemoryLayout<Int>.size
        sysctlbyname("hw.perflevel1.logicalcpu", &eCount, &size, nil, 0)  // E-cores
        sysctlbyname("hw.perflevel0.logicalcpu", &pCount, &size, nil, 0)  // P-cores
        self.eCoreCount = eCount
        self.pCoreCount = pCount
        super.init(label: label)
    }

    override func read() {
        let usage = collectUsage()
        publish(usage)
    }

    // MARK: - Data collection

    private func collectUsage() -> CPUUsage {
        let (totalUsage, userUsage, systemUsage, idleUsage, cores) = readCPUTicks()
        let loadAvg = readLoadAverage()
        let uptime = readUptime()
        let processes = readTopProcesses()

        return CPUUsage(
            total: totalUsage,
            user: userUsage,
            system: systemUsage,
            idle: idleUsage,
            cores: cores,
            loadAvg: loadAvg,
            uptime: uptime,
            processes: processes,
            eCoreCount: eCoreCount,
            pCoreCount: pCoreCount
        )
    }

    // MARK: - CPU ticks via host_processor_info

    private func readCPUTicks() -> (total: Double, user: Double, system: Double, idle: Double, cores: [CoreUsage]) {
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCpuInfo
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return (0, 0, 0, 1, [])
        }

        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.size))
        }

        let count = Int(numCPUs)
        var newInfo = [Int32](repeating: 0, count: count * Int(CPU_STATE_MAX))
        for i in 0 ..< count * Int(CPU_STATE_MAX) {
            newInfo[i] = info[i]
        }

        var cores: [CoreUsage] = []
        var totalUser: Double = 0
        var totalSystem: Double = 0
        var totalIdle: Double = 0

        let totalCores = eCoreCount + pCoreCount

        for i in 0 ..< count {
            let base = i * Int(CPU_STATE_MAX)
            let curUser   = Int32(newInfo[base + Int(CPU_STATE_USER)])
            let curSystem = Int32(newInfo[base + Int(CPU_STATE_SYSTEM)])
            let curIdle   = Int32(newInfo[base + Int(CPU_STATE_IDLE)])
            let curNice   = Int32(newInfo[base + Int(CPU_STATE_NICE)])

            if prevCpuInfo.count > base + Int(CPU_STATE_NICE) {
                let dUser   = Double(curUser   - prevCpuInfo[base + Int(CPU_STATE_USER)])
                let dSystem = Double(curSystem - prevCpuInfo[base + Int(CPU_STATE_SYSTEM)])
                let dIdle   = Double(curIdle   - prevCpuInfo[base + Int(CPU_STATE_IDLE)])
                let dNice   = Double(curNice   - prevCpuInfo[base + Int(CPU_STATE_NICE)])
                let dTotal  = max(dUser + dSystem + dIdle + dNice, 1)

                let userF   = dUser / dTotal
                let systemF = dSystem / dTotal
                let idleF   = dIdle / dTotal

                // Determine if this core is an E-core on Apple Silicon.
                // P-cores are indexed 0..<pCoreCount, E-cores follow.
                let isECore = totalCores > 0 && i >= pCoreCount

                cores.append(CoreUsage(
                    user: userF,
                    system: systemF,
                    idle: idleF,
                    isEfficiency: isECore
                ))

                totalUser   += dUser
                totalSystem += dSystem
                totalIdle   += dIdle
            }
        }

        prevCpuInfo = newInfo
        prevNumCPUs = count

        let grandTotal = max(totalUser + totalSystem + totalIdle, 1)
        return (
            (totalUser + totalSystem) / grandTotal,
            totalUser / grandTotal,
            totalSystem / grandTotal,
            totalIdle / grandTotal,
            cores
        )
    }

    // MARK: - Load averages

    private func readLoadAverage() -> (Double, Double, Double) {
        var avg = [Double](repeating: 0, count: 3)
        getloadavg(&avg, 3)
        return (avg[0], avg[1], avg[2])
    }

    // MARK: - Uptime

    private func readUptime() -> TimeInterval {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.stride
        sysctlbyname("kern.boottime", &boottime, &size, nil, 0)
        let now = Date().timeIntervalSince1970
        let boot = Double(boottime.tv_sec) + Double(boottime.tv_usec) / 1_000_000
        return now - boot
    }

    // MARK: - Top processes

    private func readTopProcesses() -> [CPUProcess] {
        var pids = [Int32](repeating: 0, count: 4096)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.size))
        guard count > 0 else { return [] }

        var results: [CPUProcess] = []
        for i in 0 ..< Int(count) {
            let pid = pids[i]
            guard pid > 0 else { continue }

            var info = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.size)
            let ret = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size)
            guard ret > 0 else { continue }

            // pti_total_user + pti_total_system are in nanoseconds; we compare to previous
            // For simplicity use pti_threads_user as a proxy (like Activity Monitor)
            let cpuUsage = Double(info.pti_total_user + info.pti_total_system) / 1_000_000_000

            var nameBuffer = [CChar](repeating: 0, count: Int(MAXCOMLEN) + 1)
            proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            let name = String(cString: nameBuffer)
            guard !name.isEmpty else { continue }

            results.append(CPUProcess(pid: pid, name: name, cpuUsage: cpuUsage))
        }

        // Sort by CPU usage, return top 5
        return Array(results.sorted { $0.cpuUsage > $1.cpuUsage }.prefix(5))
    }
}
