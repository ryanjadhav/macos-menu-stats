import AppKit
import SwiftUI

// MARK: - Menu bar widget view

struct CPUWidgetView: View {
    var usage: Double      // 0.0 – 1.0
    var history: [Double]
    var type: WidgetType
    let color = Color.blue

    var body: some View {
        switch type {
        case .text:
            textView
        case .barGraph:
            barView
        case .lineGraph:
            lineView
        case .ring:
            ringView
        }
    }

    private var textView: some View {
        Text(String(format: "%d%%", Int(usage * 100)))
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.primary)
            .frame(height: 22)
    }

    private var barView: some View {
        HStack(spacing: 3) {
            Text("CPU")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            MiniBarView(fraction: usage, color: color, width: 38, height: 10)
        }
        .frame(height: 22)
        .padding(.horizontal, 3)
    }

    private var lineView: some View {
        HStack(spacing: 3) {
            Text("CPU")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            SparklineView(dataPoints: history, color: color, width: 44, height: 14)
        }
        .frame(height: 22)
        .padding(.horizontal, 3)
    }

    private var ringView: some View {
        HStack(spacing: 3) {
            RingView(fraction: usage, color: color, diameter: 16, ringWidth: 2.5)
            Text(String(format: "%d%%", Int(usage * 100)))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .frame(height: 22)
        .padding(.horizontal, 3)
    }
}

// MARK: - Widget controller

final class CPUWidget: BaseWidget {
    private var popup: SwiftUIPopup<CPUPopupView>?
    private var currentData: CPUUsage?
    private var history: [Double] = []

    init() {
        super.init(moduleID: "cpu")
        setupPopup()
    }

    func update(with data: CPUUsage) {
        currentData = data
        history.append(data.total)
        if history.count > 60 { history.removeFirst() }

        let view = CPUWidgetView(
            usage: data.total,
            history: history,
            type: widgetType
        )
        let width: CGFloat = widgetType == .text ? 54 : 80
        setView(view, width: width)

        // Update popup if visible
        if let popup = popup, popup.isVisible, let data = currentData {
            popup.updateContent(CPUPopupView(data: data, history: history))
        }
    }

    private func setupPopup() {
        let initialData = CPUUsage(
            total: 0, user: 0, system: 0, idle: 1,
            cores: [], loadAvg: (0, 0, 0), uptime: 0,
            processes: [], eCoreCount: 0, pCoreCount: 0
        )
        popup = SwiftUIPopup(rootView: CPUPopupView(data: initialData, history: []))
    }

    override func buttonClicked() {
        guard let button = statusItem.button else { return }
        if let data = currentData {
            popup?.updateContent(CPUPopupView(data: data, history: history))
        }
        popup?.toggle(relativeTo: button)
    }
}
