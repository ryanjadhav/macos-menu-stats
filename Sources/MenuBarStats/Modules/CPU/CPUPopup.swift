import SwiftUI

struct CPUPopupView: View {
    var data: CPUUsage
    var history: [Double]

    private let accentColor = Color.blue
    private let eCoreColor = Color.blue
    private let pCoreColor = Color.indigo

    var body: some View {
        PopupContainer {
            // Header — large readout
            headerSection

            // History graph
            if history.count >= 2 {
                LineGraphView(
                    dataPoints: history,
                    color: accentColor,
                    lineWidth: 1.5,
                    showFill: true,
                    showGuides: true
                )
                .frame(height: 56)
            }

            Divider().opacity(0.3)

            // Per-core bars
            if !data.cores.isEmpty {
                coreSection
                Divider().opacity(0.3)
            }

            // System info
            systemInfoSection

            Divider().opacity(0.3)

            // Top processes
            if !data.processes.isEmpty {
                processSection
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CPU")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(String(format: "%.0f%%", data.total * 100))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                DataRow(label: "User", value: String(format: "%.1f%%", data.user * 100))
                DataRow(label: "System", value: String(format: "%.1f%%", data.system * 100))
                DataRow(label: "Idle", value: String(format: "%.1f%%", data.idle * 100))
            }
            .frame(width: 130)
        }
    }

    private var coreSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "Cores")

            let showSeparateTypes = data.eCoreCount > 0 && data.pCoreCount > 0

            if showSeparateTypes {
                // P-cores first
                let pCores = data.cores.filter { !$0.isEfficiency }
                if !pCores.isEmpty {
                    Text("Performance")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    ForEach(Array(pCores.enumerated()), id: \.offset) { i, core in
                        CoreBarRow(index: i, core: core, color: pCoreColor, label: "P")
                    }
                }
                // E-cores
                let eCores = data.cores.filter { $0.isEfficiency }
                if !eCores.isEmpty {
                    Text("Efficiency")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                    ForEach(Array(eCores.enumerated()), id: \.offset) { i, core in
                        CoreBarRow(index: i, core: core, color: eCoreColor, label: "E")
                    }
                }
            } else {
                ForEach(Array(data.cores.enumerated()), id: \.offset) { i, core in
                    CoreBarRow(index: i, core: core, color: accentColor, label: nil)
                }
            }
        }
    }

    private var systemInfoSection: some View {
        VStack(spacing: 3) {
            SectionHeader(title: "System")
            HStack {
                Text("Load avg")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.2f  %.2f  %.2f",
                            data.loadAvg.0, data.loadAvg.1, data.loadAvg.2))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            DataRow(label: "Uptime", value: formatUptime(data.uptime))
        }
    }

    private var processSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "Top Processes")
            ProcessListView(
                processes: data.processes.map {
                    ProcessInfo(
                        id: $0.pid,
                        name: $0.name,
                        value: String(format: "%.1f%%", $0.cpuUsage),
                        iconImage: appIcon(for: $0.name)
                    )
                },
                accentColor: accentColor
            )
        }
    }

    // MARK: - Helpers

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let d = s / 86400
        let h = (s % 86400) / 3600
        let m = (s % 3600) / 60
        if d > 0 { return "\(d)d \(h)h \(m)m" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

// MARK: - Core bar row

private struct CoreBarRow: View {
    var index: Int
    var core: CoreUsage
    var color: Color
    var label: String?

    var body: some View {
        HStack(spacing: 6) {
            Text("\(label ?? "Core") \(index)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            BarView(fraction: core.total, color: color, height: 6)
            Text(String(format: "%2.0f%%", core.total * 100))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}
