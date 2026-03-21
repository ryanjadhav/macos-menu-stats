import SwiftUI

struct SensorsPopupView: View {
    var data: SensorsData

    var body: some View {
        PopupContainer {
            headerSection

            if !data.temperatures.isEmpty {
                Divider().opacity(0.3)
                temperatureSection
            }

            if !data.fans.isEmpty {
                Divider().opacity(0.3)
                fanSection
            }

            if data.temperatures.isEmpty && data.fans.isEmpty {
                Text("No sensor data available")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SENSORS")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                if let primary = data.temperatures.first(where: { $0.label == "CPU" }) ?? data.temperatures.first {
                    Text(String(format: "%.0f°C", primary.celsius))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(tempColor(primary.level))
                } else {
                    Text("—")
                        .font(.system(size: 28, weight: .bold))
                }
            }
            Spacer()
            if let fan = data.fans.first {
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "fan")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f RPM", fan.currentRPM))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
            }
        }
    }

    private var temperatureSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "Temperatures")
            ForEach(data.temperatures) { reading in
                TempRow(reading: reading)
            }
        }
    }

    private var fanSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Fans")
            ForEach(data.fans) { fan in
                FanRow(fan: fan)
            }
        }
    }

    private func tempColor(_ level: TemperatureReading.TempLevel) -> Color {
        switch level {
        case .normal:   return .primary
        case .warning:  return .yellow
        case .critical: return .red
        }
    }
}

private struct TempRow: View {
    var reading: TemperatureReading

    var body: some View {
        HStack {
            Circle()
                .fill(levelColor)
                .frame(width: 6, height: 6)
            Text(reading.label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "%.1f°C", reading.celsius))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(levelColor)
        }
    }

    private var levelColor: Color {
        switch reading.level {
        case .normal:   return .green
        case .warning:  return .yellow
        case .critical: return .red
        }
    }
}

private struct FanRow: View {
    var fan: FanReading

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(fan.label)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f / %.0f RPM", fan.currentRPM, fan.maxRPM))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }
            BarView(fraction: fan.fraction, color: fanColor(fan.fraction), height: 5)
        }
    }

    private func fanColor(_ fraction: Double) -> Color {
        switch fraction {
        case ..<0.5:  return .green
        case ..<0.75: return .yellow
        default:      return .red
        }
    }
}
