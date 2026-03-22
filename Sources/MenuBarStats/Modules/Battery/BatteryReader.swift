import Foundation
import IOKit.ps

// MARK: - Data models

struct BatteryData {
    var chargePercent: Double        // 0.0 – 100.0
    var isCharging: Bool
    var isPluggedIn: Bool
    var isFull: Bool
    var timeToEmpty: Int?            // minutes, nil if unknown
    var timeToFull: Int?             // minutes, nil if unknown or not charging
    var health: Double?              // 0.0 – 100.0
    var cycleCount: Int?
    var temperature: Double?         // °C, from SMC
    var currentDraw: Double?         // Watts (positive = discharging, negative = charging)
    var processes: [BatteryProcess]
}

struct BatteryProcess {
    var pid: Int32
    var name: String
    var energyImpact: Double   // relative energy impact score
}

// MARK: - Reader

final class BatteryReader: BaseReader<BatteryData> {
    private let smc = SMCKit.shared

    override init(label: String = "battery") {
        super.init(label: label)
    }

    override func read() {
        if let data = collectData() {
            publish(data)
        }
    }

    private func collectData() -> BatteryData? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return nil }
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]

        guard !sources.isEmpty else { return nil }

        // Take the first battery source
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)
                    .takeUnretainedValue() as? [String: AnyObject] else { continue }

            // Check it is actually a battery
            let type = desc[kIOPSTypeKey] as? String ?? ""
            guard type == kIOPSInternalBatteryType else { continue }

            let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximum = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let chargePercent = maximum > 0 ? Double(current) / Double(maximum) * 100.0 : 0

            let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let isPluggedIn = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            let isFull = desc["Is Charged"] as? Bool ?? false

            let timeToEmpty = desc[kIOPSTimeToEmptyKey] as? Int
            let timeToFull  = desc[kIOPSTimeToFullChargeKey] as? Int

            // Battery health & cycle count from extended attributes
            let health     = (desc[kIOPSBatteryHealthKey] as? String).map { healthToPercent($0) }
            let cycleCount = desc["CycleCount"] as? Int

            // Temperature via SMC
            let temperature = smc.readTemperature(SMCSensorKey.batteryTemp)

            // Power draw via SMC (PSTR = system power, positive when consuming)
            let currentDraw = readPowerDraw()

            let processes = readTopProcesses()

            return BatteryData(
                chargePercent: chargePercent,
                isCharging: isCharging,
                isPluggedIn: isPluggedIn,
                isFull: isFull,
                timeToEmpty: timeToEmpty,
                timeToFull: timeToFull,
                health: health,
                cycleCount: cycleCount,
                temperature: temperature,
                currentDraw: currentDraw,
                processes: processes
            )
        }
        return nil
    }

    // MARK: - Helpers

    private func healthToPercent(_ health: String) -> Double {
        switch health.lowercased() {
        case "good":    return 100
        case "fair":    return 75
        case "poor":    return 50
        default:
            // Sometimes Apple reports a numeric string
            return Double(health) ?? 100
        }
    }

    private func readPowerDraw() -> Double? {
        // Try to read system power consumption via SMC key PSTR (Power System Total)
        // This is an sp78 signed fixed-point value in Watts
        let key = SMCKey("PSTR")
        return smc.readTemperature(key)  // sp78 decode is same as temperature
    }

    private func readTopProcesses() -> [BatteryProcess] {
        var pids = [Int32](repeating: 0, count: 4096)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.size))
        guard count > 0 else { return [] }

        var results: [BatteryProcess] = []
        for i in 0 ..< Int(count) {
            let pid = pids[i]
            guard pid > 0 else { continue }

            var info = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size) > 0 else { continue }

            // Energy impact proxy: CPU time (user + system nanoseconds)
            let energy = Double(info.pti_total_user + info.pti_total_system)
            guard energy > 0 else { continue }

            var nameBuffer = [CChar](repeating: 0, count: Int(MAXCOMLEN) + 1)
            proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            let name = String(cString: nameBuffer)
            guard !name.isEmpty else { continue }

            results.append(BatteryProcess(pid: pid, name: name, energyImpact: energy))
        }

        return Array(results.sorted { $0.energyImpact > $1.energyImpact }.prefix(5))
    }
}
