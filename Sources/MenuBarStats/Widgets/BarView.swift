import SwiftUI

/// A horizontal bar showing a single fill fraction (0.0–1.0).
struct BarView: View {
    var fraction: Double  // 0.0 – 1.0
    var color: Color
    var height: CGFloat = 6
    var cornerRadius: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: height)

                // Fill
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(max(0, min(1, fraction))), height: height)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }
}

/// A stacked horizontal bar (multiple segments that sum to 1.0).
struct StackedBarView: View {
    struct Segment {
        var fraction: Double
        var color: Color
        var label: String
    }

    var segments: [Segment]
    var height: CGFloat = 8
    var cornerRadius: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: height)

                HStack(spacing: 0) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                        Rectangle()
                            .fill(seg.color)
                            .frame(
                                width: geo.size.width * CGFloat(max(0, min(1, seg.fraction))),
                                height: height
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }
}

/// Mini bar for menu bar widget (fixed narrow size).
struct MiniBarView: View {
    var fraction: Double
    var color: Color
    var width: CGFloat = 40
    var height: CGFloat = 12

    var body: some View {
        BarView(fraction: fraction, color: color, height: height)
            .frame(width: width, height: height)
    }
}
