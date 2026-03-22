import SwiftUI

/// A donut (ring) chart for showing proportional breakdowns (e.g. memory categories).
struct PieView: View {
    struct Slice {
        var fraction: Double  // 0.0 – 1.0
        var color: Color
        var label: String
    }

    var slices: [Slice]
    var innerFraction: CGFloat = 0.55  // inner radius as fraction of outer
    var lineWidth: CGFloat? = nil       // if set, overrides innerFraction for ring thickness

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let outerRadius = size / 2
            let innerRadius = lineWidth.map { outerRadius - $0 } ?? (outerRadius * innerFraction)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                // Background ring
                Circle()
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: outerRadius - innerRadius)
                    .frame(width: size, height: size)
                    .position(center)

                // Slices
                Canvas { context, _ in
                    var startAngle: Double = -90  // start from top
                    for slice in slices {
                        let endAngle = startAngle + slice.fraction * 360
                        var path = Path()
                        path.addArc(
                            center: center,
                            radius: (outerRadius + innerRadius) / 2,
                            startAngle: .degrees(startAngle),
                            endAngle: .degrees(endAngle),
                            clockwise: false
                        )
                        context.stroke(
                            path,
                            with: .color(slice.color),
                            lineWidth: outerRadius - innerRadius
                        )
                        startAngle = endAngle
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}

/// Small ring variant for menu bar widgets.
struct RingView: View {
    var fraction: Double  // 0.0 – 1.0
    var color: Color
    var diameter: CGFloat = 18
    var ringWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: ringWidth)
            Circle()
                .trim(from: 0, to: CGFloat(fraction))
                .stroke(color, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: diameter, height: diameter)
    }
}
