import AppKit
import SwiftUI

struct NetworkWidgetView: View {
    var stats: NetworkStats
    var type: WidgetType
    let upColor   = Color.orange
    let downColor = Color.green

    var body: some View {
        switch type {
        case .text, .barGraph:
            arrowsView
        case .lineGraph:
            arrowsView
        case .ring:
            arrowsView
        }
    }

    private var arrowsView: some View {
        VStack(alignment: .trailing, spacing: 0) {
            HStack(spacing: 2) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(downColor)
                Text(formatThroughput(stats.downloadBytesPerSec))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            HStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(upColor)
                Text(formatThroughput(stats.uploadBytesPerSec))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 3)
    }
}

final class NetworkWidget: BaseWidget {
    private var popup: SwiftUIPopup<NetworkPopupView>?
    private var currentData: NetworkStats?

    init() {
        super.init(moduleID: "network")
        setupPopup()
    }

    func update(with data: NetworkStats) {
        currentData = data
        let view = NetworkWidgetView(stats: data, type: widgetType)
        setView(view, width: 90)

        if let popup = popup, popup.isVisible, let data = currentData {
            popup.updateContent(NetworkPopupView(stats: data))
        }
    }

    private func setupPopup() {
        let empty = NetworkStats(
            downloadBytesPerSec: 0, uploadBytesPerSec: 0,
            downloadHistory: [], uploadHistory: [],
            interfaces: [], publicIP: nil, processes: []
        )
        popup = SwiftUIPopup(rootView: NetworkPopupView(stats: empty))
    }

    override func buttonClicked() {
        guard let button = statusItem.button else { return }
        if let data = currentData {
            popup?.updateContent(NetworkPopupView(stats: data))
        }
        popup?.toggle(relativeTo: button)
    }
}
