import AppKit
import SwiftUI

struct SensorsWidgetView: View {
    var data: SensorsData
    var type: WidgetType

    private var primaryTemp: TemperatureReading? {
        data.temperatures.first(where: { $0.label == "CPU" }) ?? data.temperatures.first
    }
    private var primaryFan: FanReading? { data.fans.first }

    var body: some View {
        switch type {
        case .text, .barGraph, .lineGraph, .ring:
            compactView
        }
    }

    private var compactView: some View {
        HStack(spacing: 4) {
            if let temp = primaryTemp {
                HStack(spacing: 2) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 9))
                        .foregroundStyle(tempColor(temp.level))
                    Text(String(format: "%.0f°", temp.celsius))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                }
            }
            if let fan = primaryFan {
                HStack(spacing: 2) {
                    Image(systemName: "fan")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f", fan.currentRPM))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 3)
    }

    private func tempColor(_ level: TemperatureReading.TempLevel) -> Color {
        switch level {
        case .normal:   return .green
        case .warning:  return .yellow
        case .critical: return .red
        }
    }
}

final class SensorsWidget: BaseWidget {
    private var popup: SwiftUIPopup<SensorsPopupView>?
    private var currentData: SensorsData?

    init() {
        super.init(moduleID: "sensors")
        setupPopup()
    }

    func update(with data: SensorsData) {
        currentData = data
        let view = SensorsWidgetView(data: data, type: widgetType)
        setView(view, width: 100)

        if let popup = popup, popup.isVisible, let data = currentData {
            popup.updateContent(SensorsPopupView(data: data))
        }
    }

    private func setupPopup() {
        popup = SwiftUIPopup(rootView: SensorsPopupView(
            data: SensorsData(temperatures: [], fans: [])
        ))
    }

    override func buttonClicked() {
        guard let button = statusItem.button else { return }
        if let data = currentData {
            popup?.updateContent(SensorsPopupView(data: data))
        }
        popup?.toggle(relativeTo: button)
    }
}
