import AppKit
import SwiftUI

struct BatteryWidgetView: View {
    var data: BatteryData

    var body: some View {
        HStack(spacing: 3) {
            // Battery icon with fill level
            BatteryIconView(
                fraction: data.chargePercent / 100.0,
                isCharging: data.isCharging
            )
            .frame(width: 22, height: 11)

            // Percentage
            Text(String(format: "%.0f%%", data.chargePercent))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)

            // Time remaining (compact)
            if let minutes = data.isCharging ? data.timeToFull : data.timeToEmpty {
                Text(formatMinutes(minutes, short: true))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 3)
    }

    private func formatMinutes(_ minutes: Int, short: Bool) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if short {
            return h > 0 ? "\(h)h\(m)m" : "\(m)m"
        }
        return h > 0 ? "\(h)h \(m)m" : "\(m) min"
    }
}

/// Custom battery icon drawn with Canvas.
struct BatteryIconView: View {
    var fraction: Double  // 0.0 – 1.0
    var isCharging: Bool

    private var fillColor: Color {
        if isCharging { return .green }
        switch fraction {
        case ..<0.2:  return .red
        case ..<0.4:  return .yellow
        default:      return .primary
        }
    }

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cornerR: CGFloat = 2
            let capW: CGFloat = 2.5
            let capH: CGFloat = h * 0.4
            let bodyW = w - capW

            // Body outline
            let bodyRect = CGRect(x: 0, y: 0, width: bodyW, height: h)
            let bodyPath = RoundedRectangle(cornerRadius: cornerR).path(in: bodyRect)
            context.stroke(bodyPath, with: .foreground, lineWidth: 1)

            // Fill
            let fillW = max(0, (bodyW - 4) * CGFloat(fraction))
            let fillRect = CGRect(x: 2, y: 2, width: fillW, height: h - 4)
            let fillPath = RoundedRectangle(cornerRadius: 1).path(in: fillRect)
            context.fill(fillPath, with: .color(fillColor))

            // Cap (positive terminal)
            let capRect = CGRect(x: bodyW, y: (h - capH) / 2, width: capW, height: capH)
            let capPath = RoundedRectangle(cornerRadius: 1).path(in: capRect)
            context.fill(capPath, with: .color(.secondary.opacity(0.6)))

            // Lightning bolt if charging
            if isCharging {
                let boltX = bodyW / 2 - 3
                var bolt = Path()
                bolt.move(to:    CGPoint(x: boltX + 5, y: 1))
                bolt.addLine(to: CGPoint(x: boltX + 2, y: h / 2 - 1))
                bolt.addLine(to: CGPoint(x: boltX + 4, y: h / 2 - 1))
                bolt.addLine(to: CGPoint(x: boltX + 1, y: h - 1))
                bolt.addLine(to: CGPoint(x: boltX + 5, y: h / 2 + 1))
                bolt.addLine(to: CGPoint(x: boltX + 3, y: h / 2 + 1))
                bolt.closeSubpath()
                context.fill(bolt, with: .color(.white.opacity(0.9)))
            }
        }
    }
}

final class BatteryWidget: BaseWidget {
    private var popup: SwiftUIPopup<BatteryPopupView>?
    private var currentData: BatteryData?

    init() {
        super.init(moduleID: "battery")
        setupPopup()
    }

    func update(with data: BatteryData) {
        currentData = data
        let view = BatteryWidgetView(data: data)
        setView(view, width: 90)

        if let popup = popup, popup.isVisible, let data = currentData {
            popup.updateContent(BatteryPopupView(data: data))
        }
    }

    private func setupPopup() {
        let empty = BatteryData(
            chargePercent: 0, isCharging: false, isPluggedIn: false, isFull: false,
            timeToEmpty: nil, timeToFull: nil, health: nil, cycleCount: nil,
            temperature: nil, currentDraw: nil, processes: []
        )
        popup = SwiftUIPopup(rootView: BatteryPopupView(data: empty))
    }

    override func buttonClicked() {
        guard let button = statusItem.button else { return }
        if let data = currentData {
            popup?.updateContent(BatteryPopupView(data: data))
        }
        popup?.toggle(relativeTo: button)
    }
}
