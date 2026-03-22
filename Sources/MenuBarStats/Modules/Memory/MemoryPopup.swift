import SwiftUI

struct MemoryPopupView: View {
    var data: MemoryUsage
    var history: [Double]

    private let accentColor = Color.purple
    private let usedColor = Color.purple
    private let wiredColor = Color.indigo
    private let compressedColor = Color.orange
    private let freeColor = Color.green.opacity(0.7)

    var body: some View {
        PopupContainer {
            headerSection

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

            donutSection

            Divider().opacity(0.3)

            swapPressureSection

            if !data.processes.isEmpty {
                Divider().opacity(0.3)
                processSection
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MEMORY")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(String(format: "%.0f%%", data.usedFraction * 100))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatBytes(Double(data.used)))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                Text("/ \(formatBytes(Double(data.total)))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var donutSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Breakdown")

            HStack(spacing: 12) {
                // Donut chart
                let total = Double(data.total)
                PieView(
                    slices: [
                        .init(fraction: total > 0 ? Double(data.active) / total : 0, color: usedColor.opacity(0.8), label: "Active"),
                        .init(fraction: total > 0 ? Double(data.wired) / total : 0, color: wiredColor, label: "Wired"),
                        .init(fraction: total > 0 ? Double(data.compressed) / total : 0, color: compressedColor, label: "Compressed"),
                        .init(fraction: total > 0 ? Double(data.inactive) / total : 0, color: Color.secondary.opacity(0.3), label: "Inactive"),
                        .init(fraction: total > 0 ? Double(data.free) / total : 0, color: freeColor, label: "Free"),
                    ],
                    lineWidth: 10
                )
                .frame(width: 70, height: 70)

                // Legend
                VStack(alignment: .leading, spacing: 3) {
                    MemoryRow(label: "Active", value: formatBytes(Double(data.active)), color: usedColor.opacity(0.8))
                    MemoryRow(label: "Wired", value: formatBytes(Double(data.wired)), color: wiredColor)
                    MemoryRow(label: "Compressed", value: formatBytes(Double(data.compressed)), color: compressedColor)
                    MemoryRow(label: "Inactive", value: formatBytes(Double(data.inactive)), color: .secondary)
                    MemoryRow(label: "Free", value: formatBytes(Double(data.free)), color: freeColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var swapPressureSection: some View {
        VStack(spacing: 3) {
            SectionHeader(title: "System")

            // Memory pressure
            HStack {
                Text("Pressure")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(data.pressureLevel.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(pressureColor)
            }

            // Swap
            DataRow(
                label: "Swap Used",
                value: "\(formatBytes(Double(data.swapUsed))) / \(formatBytes(Double(data.swapTotal)))"
            )
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
                        value: formatBytes(Double($0.residentBytes)),
                        iconImage: appIcon(for: $0.name)
                    )
                },
                accentColor: accentColor
            )
        }
    }

    private var pressureColor: Color {
        switch data.pressureLevel {
        case .normal:   return .green
        case .warning:  return .yellow
        case .critical: return .red
        }
    }
}

private struct MemoryRow: View {
    var label: String
    var value: String
    var color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }
}
