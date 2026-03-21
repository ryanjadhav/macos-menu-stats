import SwiftUI

/// A scrolling line graph that shows the last N data points (0.0–1.0).
/// Used in both menu bar mini-widgets and the popup history graph.
struct LineGraphView: View {
    /// Data points in chronological order, oldest first. Values 0.0–1.0.
    var dataPoints: [Double]
    var color: Color
    var lineWidth: CGFloat = 1.5
    /// Whether to draw a gradient fill under the line.
    var showFill: Bool = true
    /// Whether to draw faint horizontal guide lines at 25%, 50%, 75%.
    var showGuides: Bool = true

    var body: some View {
        Canvas { context, size in
            guard dataPoints.count >= 2 else { return }

            let w = size.width
            let h = size.height
            let count = dataPoints.count
            let step = w / CGFloat(count - 1)

            // Guide lines
            if showGuides {
                for fraction in [0.25, 0.5, 0.75] {
                    let y = h * (1 - fraction)
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: w, y: y))
                    context.stroke(path, with: .color(.primary.opacity(0.08)), lineWidth: 0.5)
                }
            }

            // Build the line path
            var linePath = Path()
            for (i, value) in dataPoints.enumerated() {
                let x = CGFloat(i) * step
                let y = h * (1.0 - CGFloat(value))
                if i == 0 {
                    linePath.move(to: CGPoint(x: x, y: y))
                } else {
                    linePath.addLine(to: CGPoint(x: x, y: y))
                }
            }

            // Filled area
            if showFill {
                var fillPath = linePath
                fillPath.addLine(to: CGPoint(x: w, y: h))
                fillPath.addLine(to: CGPoint(x: 0, y: h))
                fillPath.closeSubpath()
                context.fill(
                    fillPath,
                    with: .linearGradient(
                        Gradient(colors: [color.opacity(0.4), color.opacity(0.0)]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: h)
                    )
                )
            }

            // Line stroke
            context.stroke(linePath, with: .color(color), lineWidth: lineWidth)
        }
    }
}

/// Compact sparkline for menu bar widget (no guides, no fill label).
struct SparklineView: View {
    var dataPoints: [Double]
    var color: Color
    var width: CGFloat = 50
    var height: CGFloat = 14

    var body: some View {
        LineGraphView(
            dataPoints: dataPoints,
            color: color,
            lineWidth: 1.0,
            showFill: true,
            showGuides: false
        )
        .frame(width: width, height: height)
    }
}
