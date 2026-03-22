import Foundation

// MARK: - Data models

struct SensorsData {
    var temperatures: [TemperatureReading]
    var fans: [FanReading]
}

struct TemperatureReading: Identifiable {
    var id: String  // SMC key string
    var label: String
    var celsius: Double
    var level: TempLevel

    enum TempLevel {
        case normal   // < 70°C
        case warning  // 70 – 84°C
        case critical // >= 85°C
    }
}

struct FanReading: Identifiable {
    var id: Int    // fan index
    var label: String
    var currentRPM: Double
    var maxRPM: Double
    var fraction: Double  // currentRPM / maxRPM
}

// MARK: - Reader

final class SensorsReader: BaseReader<SensorsData> {
    private let smc = SMCKit.shared

    // Ordered list of temperature keys to try, with friendly labels.
    private let temperatureKeys: [(key: SMCKey, label: String)] = [
        (SMCSensorKey.cpuTemp,      "CPU"),
        (SMCSensorKey.cpuDie,       "CPU Die"),
        (SMCSensorKey.cpuProximity, "CPU Proximity"),
        (SMCSensorKey.gpuTemp,      "GPU"),
        (SMCSensorKey.gpuProximity, "GPU Proximity"),
        (SMCSensorKey.batteryTemp,  "Battery"),
        (SMCSensorKey.ambientTemp,  "Ambient"),
        (SMCSensorKey.heatsink,     "Heatsink"),
    ]

    override init(label: String = "sensors") {
        super.init(label: label)
    }

    override func read() {
        publish(collectData())
    }

    private func collectData() -> SensorsData {
        let temps = readTemperatures()
        let fans  = readFans()
        return SensorsData(temperatures: temps, fans: fans)
    }

    private func readTemperatures() -> [TemperatureReading] {
        var readings: [TemperatureReading] = []
        for entry in temperatureKeys {
            guard let celsius = smc.readTemperature(entry.key) else { continue }
            let level: TemperatureReading.TempLevel
            switch celsius {
            case ..<70:  level = .normal
            case ..<85:  level = .warning
            default:     level = .critical
            }
            // Use key code string as id
            let keyStr = keyString(entry.key.code)
            readings.append(TemperatureReading(
                id: keyStr,
                label: entry.label,
                celsius: celsius,
                level: level
            ))
        }
        return readings
    }

    private func readFans() -> [FanReading] {
        var fans: [FanReading] = []

        // Read number of fans
        let fanCount = smc.readUInt8(SMCSensorKey.fanCount).map { Int($0) } ?? 2

        let rpmKeys = [SMCSensorKey.fan0CurrentRPM, SMCSensorKey.fan1CurrentRPM]
        let maxKeys = [SMCSensorKey.fan0MaxRPM,     SMCSensorKey.fan1MaxRPM]

        for i in 0 ..< min(fanCount, rpmKeys.count) {
            guard let current = smc.readRPM(rpmKeys[i]) else { continue }
            let maxRPM = smc.readRPM(maxKeys[i]) ?? 6000
            let fraction = maxRPM > 0 ? min(current / maxRPM, 1.0) : 0
            fans.append(FanReading(
                id: i,
                label: "Fan \(i + 1)",
                currentRPM: current,
                maxRPM: maxRPM,
                fraction: fraction
            ))
        }
        return fans
    }

    private func keyString(_ code: UInt32) -> String {
        var result = ""
        for i in stride(from: 24, through: 0, by: -8) {
            let char = UInt8((code >> i) & 0xFF)
            result.append(Character(UnicodeScalar(char)))
        }
        return result
    }
}
