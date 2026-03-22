import SwiftUI

struct BatteryPopupView: View {
    var data: BatteryData

    private var accentColor: Color {
        if data.isCharging { return .green }
        switch data.chargePercent {
        case ..<20:  return .red
        case ..<40:  return .yellow
        default:     return .green
        }
    }

    var body: some View {
        PopupContainer {
            headerSection

            Divider().opacity(0.3)

            statusSection

            if data.health != nil || data.cycleCount != nil {
                Divider().opacity(0.3)
                healthSection
            }

            if data.temperature != nil || data.currentDraw != nil {
                Divider().opacity(0.3)
                detailSection
            }

            if !data.processes.isEmpty {
                Divider().opacity(0.3)
                processSection
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("BATTERY")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.0f%%", data.chargePercent))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(stateLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accentColor.opacity(0.12))
                        .cornerRadius(4)
                }
            }
            Spacer()

            // Large battery ring
            ZStack {
                RingView(fraction: data.chargePercent / 100.0, color: accentColor, diameter: 48, ringWidth: 5)
                if data.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
            }
        }
    }

    private var statusSection: some View {
        VStack(spacing: 3) {
            SectionHeader(title: "Status")
            if let minutes = data.isCharging ? data.timeToFull : data.timeToEmpty {
                DataRow(
                    label: data.isCharging ? "Time to Full" : "Time Remaining",
                    value: formatMinutes(minutes)
                )
            }
            DataRow(label: "Power Source", value: data.isPluggedIn ? "AC Power" : "Battery")
        }
    }

    private var healthSection: some View {
        VStack(spacing: 3) {
            SectionHeader(title: "Battery Health")
            if let health = data.health {
                HStack {
                    Text("Condition")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", health))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(health > 80 ? .green : health > 60 ? .yellow : .red)
                }
                BarView(fraction: health / 100.0, color: health > 80 ? .green : health > 60 ? .yellow : .red, height: 5)
            }
            if let cycles = data.cycleCount {
                DataRow(label: "Cycle Count", value: "\(cycles)")
            }
        }
    }

    private var detailSection: some View {
        VStack(spacing: 3) {
            SectionHeader(title: "Details")
            if let temp = data.temperature {
                DataRow(label: "Temperature", value: String(format: "%.1f°C", temp))
            }
            if let watts = data.currentDraw {
                DataRow(label: "Power Draw", value: String(format: "%.1f W", watts))
            }
        }
    }

    private var processSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "Top Processes")
            ProcessListView(
                processes: data.processes.map {
                    let impact = $0.energyImpact / 1_000_000_000
                    return ProcessInfo(
                        id: $0.pid,
                        name: $0.name,
                        value: String(format: "%.1fs CPU", impact),
                        iconImage: appIcon(for: $0.name)
                    )
                },
                accentColor: accentColor
            )
        }
    }

    private var stateLabel: String {
        if data.isFull { return "Charged" }
        if data.isCharging { return "Charging" }
        return "Discharging"
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m) min"
    }
}
