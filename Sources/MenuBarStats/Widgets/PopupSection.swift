import SwiftUI

/// A labelled section header used throughout popup views.
struct SectionHeader: View {
    var title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .kerning(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A single data row: left label + right value.
struct DataRow: View {
    var label: String
    var value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(valueColor)
        }
    }
}

/// NSVisualEffectView wrapper for SwiftUI popup backgrounds.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// Standard popup container used by all modules.
struct PopupContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .popover, blendingMode: .behindWindow)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    content
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .frame(width: 280)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Bytes → human-readable string. e.g. 2048 → "2.0 KB"
func formatBytes(_ bytes: Double, decimals: Int = 1) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var value = bytes
    var unitIndex = 0
    while value >= 1024 && unitIndex < units.count - 1 {
        value /= 1024
        unitIndex += 1
    }
    return String(format: "%.\(decimals)f \(units[unitIndex])", value)
}

/// Bytes/sec → human-readable throughput string.
func formatThroughput(_ bytesPerSec: Double) -> String {
    formatBytes(bytesPerSec) + "/s"
}
