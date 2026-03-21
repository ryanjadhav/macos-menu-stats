import AppKit
import SwiftUI

// MARK: - Menu bar widget view

struct MemoryWidgetView: View {
    var usage: MemoryUsage
    var history: [Double]
    var type: WidgetType
    let color = Color.purple

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
        Text(String(format: "%d%%", Int(usage.usedFraction * 100)))
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.primary)
            .frame(height: 22)
    }

    private var barView: some View {
        HStack(spacing: 3) {
            Text("MEM")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            MiniBarView(fraction: usage.usedFraction, color: color, width: 38, height: 10)
        }
        .frame(height: 22)
        .padding(.horizontal, 3)
    }

    private var lineView: some View {
        HStack(spacing: 3) {
            Text("MEM")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            SparklineView(dataPoints: history, color: color, width: 44, height: 14)
        }
        .frame(height: 22)
        .padding(.horizontal, 3)
    }

    private var ringView: some View {
        HStack(spacing: 3) {
            RingView(fraction: usage.usedFraction, color: color, diameter: 16, ringWidth: 2.5)
            Text(String(format: "%d%%", Int(usage.usedFraction * 100)))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .frame(height: 22)
        .padding(.horizontal, 3)
    }
}

// MARK: - Widget controller

final class MemoryWidget: BaseWidget {
    private var popup: SwiftUIPopup<MemoryPopupView>?
    private var currentData: MemoryUsage?
    private var history: [Double] = []

    init() {
        super.init(moduleID: "memory")
        setupPopup()
    }

    func update(with data: MemoryUsage) {
        currentData = data
        history.append(data.usedFraction)
        if history.count > 60 { history.removeFirst() }

        let view = MemoryWidgetView(usage: data, history: history, type: widgetType)
        let width: CGFloat = widgetType == .text ? 52 : 80
        setView(view, width: width)

        if let popup = popup, popup.isVisible, let data = currentData {
            popup.updateContent(MemoryPopupView(data: data, history: history))
        }
    }

    private func setupPopup() {
        let empty = MemoryUsage(
            total: 0, used: 0, wired: 0, active: 0, inactive: 0,
            compressed: 0, free: 0, swapUsed: 0, swapTotal: 0,
            pressureLevel: .normal, usedFraction: 0, processes: []
        )
        popup = SwiftUIPopup(rootView: MemoryPopupView(data: empty, history: []))
    }

    override func buttonClicked() {
        guard let button = statusItem.button else { return }
        if let data = currentData {
            popup?.updateContent(MemoryPopupView(data: data, history: history))
        }
        popup?.toggle(relativeTo: button)
    }
}
