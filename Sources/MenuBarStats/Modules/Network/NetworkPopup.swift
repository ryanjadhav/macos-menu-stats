import SwiftUI

struct NetworkPopupView: View {
    var stats: NetworkStats

    private let downColor = Color.green
    private let upColor   = Color.orange

    var body: some View {
        PopupContainer {
            headerSection

            if stats.downloadHistory.count >= 2 || stats.uploadHistory.count >= 2 {
                historyGraph
            }

            Divider().opacity(0.3)

            if !stats.interfaces.isEmpty {
                interfaceSection
                Divider().opacity(0.3)
            }

            ipSection

            if !stats.processes.isEmpty {
                Divider().opacity(0.3)
                processSection
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("NETWORK")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down").foregroundStyle(downColor)
                    Text(formatThroughput(stats.downloadBytesPerSec))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up").foregroundStyle(upColor)
                    Text(formatThroughput(stats.uploadBytesPerSec))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                }
            }
            Spacer()
        }
    }

    private var historyGraph: some View {
        ZStack {
            if stats.uploadHistory.count >= 2 {
                LineGraphView(dataPoints: stats.uploadHistory, color: upColor,
                              lineWidth: 1.5, showFill: true, showGuides: false)
            }
            if stats.downloadHistory.count >= 2 {
                LineGraphView(dataPoints: stats.downloadHistory, color: downColor,
                              lineWidth: 1.5, showFill: false, showGuides: true)
            }
        }
        .frame(height: 56)
        .overlay(alignment: .topLeading) {
            HStack(spacing: 8) {
                legendDot(color: downColor, label: "Download")
                legendDot(color: upColor,   label: "Upload")
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

    private var interfaceSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "Interfaces")
            ForEach(stats.interfaces, id: \.name) { iface in
                InterfaceRow(iface: iface)
            }
        }
    }

    private var ipSection: some View {
        VStack(spacing: 3) {
            SectionHeader(title: "IP Addresses")
            if let ip = stats.publicIP {
                DataRow(label: "Public IP", value: ip)
            } else {
                DataRow(label: "Public IP", value: "—")
            }
            if let local = stats.interfaces.first(where: { $0.isActive })?.localIPv4 {
                DataRow(label: "Local IP", value: local)
            }
        }
    }

    private var processSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "Top Processes")
            ProcessListView(
                processes: stats.processes.map {
                    ProcessInfo(
                        id: $0.pid,
                        name: $0.name,
                        value: "↓\(formatBytes(Double($0.rxBytes), decimals: 0))",
                        iconImage: appIcon(for: $0.name)
                    )
                },
                accentColor: .green
            )
        }
    }
}

private struct InterfaceRow: View {
    var iface: NetworkInterface

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(iface.displayName)
                    .font(.system(size: 12, weight: .medium))
                if let ip = iface.localIPv4 {
                    Text(ip)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Circle()
                .fill(iface.isActive ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 6, height: 6)
        }
    }

    private var iconName: String {
        switch iface.type {
        case .wifi:     return "wifi"
        case .ethernet: return "cable.connector"
        case .loopback: return "arrow.triangle.2.circlepath"
        case .other:    return "network"
        }
    }
}
