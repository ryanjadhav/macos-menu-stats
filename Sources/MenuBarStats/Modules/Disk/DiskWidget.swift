import AppKit
import SwiftUI

struct DiskWidgetView: View {
    var stats: DiskStats
    var history: [Double]
    var type: WidgetType
    let color = Color.orange

    private var primaryVolume: DiskInfo? { stats.volumes.first }

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
        HStack(spacing: 4) {
            Text("DSK")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            if let vol = primaryVolume {
                Text(String(format: "%d%%", Int(vol.usedFraction * 100)))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
        .frame(height: 22)
    }

    private var barView: some View {
        HStack(spacing: 3) {
            Text("DSK")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            if let vol = primaryVolume {
                MiniBarView(fraction: vol.usedFraction, color: color, width: 38, height: 10)
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 3)
    }

    private var lineView: some View {
        // Show R/W arrows + speed
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 7))
                    .foregroundStyle(.green)
                Text(formatThroughput(stats.activity.readBytesPerSec))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            HStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 7))
                    .foregroundStyle(.orange)
                Text(formatThroughput(stats.activity.writeBytesPerSec))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 3)
    }

    private var ringView: some View {
        HStack(spacing: 3) {
            if let vol = primaryVolume {
                RingView(fraction: vol.usedFraction, color: color, diameter: 16, ringWidth: 2.5)
                Text(String(format: "%d%%", Int(vol.usedFraction * 100)))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 3)
    }
}

final class DiskWidget: BaseWidget {
    private var popup: SwiftUIPopup<DiskPopupView>?
    private var currentData: DiskStats?
    private var history: [Double] = []

    init() {
        super.init(moduleID: "disk")
        setupPopup()
    }

    func update(with data: DiskStats) {
        currentData = data
        let usedFraction = data.volumes.first?.usedFraction ?? 0
        history.append(usedFraction)
        if history.count > 60 { history.removeFirst() }

        let view = DiskWidgetView(stats: data, history: history, type: widgetType)
        let width: CGFloat = widgetType == .lineGraph ? 90 : 80
        setView(view, width: width)

        if let popup = popup, popup.isVisible, let data = currentData {
            popup.updateContent(DiskPopupView(data: data, history: history))
        }
    }

    private func setupPopup() {
        let empty = DiskStats(
            volumes: [],
            activity: DiskActivity(readBytesPerSec: 0, writeBytesPerSec: 0,
                                   readHistory: [], writeHistory: [], processes: [])
        )
        popup = SwiftUIPopup(rootView: DiskPopupView(data: empty, history: []))
    }

    override func buttonClicked() {
        guard let button = statusItem.button else { return }
        if let data = currentData {
            popup?.updateContent(DiskPopupView(data: data, history: history))
        }
        popup?.toggle(relativeTo: button)
    }
}
