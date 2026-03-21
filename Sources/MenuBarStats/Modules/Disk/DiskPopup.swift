import SwiftUI

struct DiskPopupView: View {
    var data: DiskStats
    var history: [Double]

    private let readColor  = Color.green
    private let writeColor = Color.orange

    var body: some View {
        PopupContainer {
            headerSection

            // R/W history dual graph
            if data.activity.readHistory.count >= 2 || data.activity.writeHistory.count >= 2 {
                activityGraph
            }

            Divider().opacity(0.3)

            if !data.volumes.isEmpty {
                volumeSection
                Divider().opacity(0.3)
            }

            activitySection

            if !data.activity.processes.isEmpty {
                Divider().opacity(0.3)
                processSection
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DISK")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                if let vol = data.volumes.first {
                    Text(String(format: "%.0f%%", vol.usedFraction * 100))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                } else {
                    Text("—")
                        .font(.system(size: 28, weight: .bold))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down").font(.system(size: 10)).foregroundStyle(readColor)
                    Text(formatThroughput(data.activity.readBytesPerSec))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up").font(.system(size: 10)).foregroundStyle(writeColor)
                    Text(formatThroughput(data.activity.writeBytesPerSec))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
            }
        }
    }

    private var activityGraph: some View {
        ZStack {
            if data.activity.writeHistory.count >= 2 {
                LineGraphView(dataPoints: data.activity.writeHistory, color: writeColor,
                              lineWidth: 1.5, showFill: true, showGuides: false)
            }
            if data.activity.readHistory.count >= 2 {
                LineGraphView(dataPoints: data.activity.readHistory, color: readColor,
                              lineWidth: 1.5, showFill: false, showGuides: true)
            }
        }
        .frame(height: 56)
        .overlay(alignment: .topLeading) {
            HStack(spacing: 8) {
                legendDot(color: readColor, label: "Read")
                legendDot(color: writeColor, label: "Write")
            }
            .padding(.leading, 2)
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Volumes")
            ForEach(data.volumes, id: \.mountPoint) { vol in
                VolumeRow(info: vol)
            }
        }
    }

    private var activitySection: some View {
        VStack(spacing: 3) {
            SectionHeader(title: "Activity")
            DataRow(label: "Read", value: formatThroughput(data.activity.readBytesPerSec), valueColor: readColor)
            DataRow(label: "Write", value: formatThroughput(data.activity.writeBytesPerSec), valueColor: writeColor)
        }
    }

    private var processSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "Top Processes")
            ProcessListView(
                processes: data.activity.processes.map {
                    ProcessInfo(
                        id: $0.pid,
                        name: $0.name,
                        value: "R:\(formatBytes(Double($0.readBytes), decimals: 0))",
                        iconImage: appIcon(for: $0.name)
                    )
                },
                accentColor: .orange
            )
        }
    }
}

private struct VolumeRow: View {
    var info: DiskInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Image(systemName: info.isInternal ? "internaldrive" : "externaldrive")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(info.name)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(formatBytes(Double(info.free))) free")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            BarView(fraction: info.usedFraction, color: .orange, height: 5)
            HStack {
                Text(formatBytes(Double(info.used)))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatBytes(Double(info.total)))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
