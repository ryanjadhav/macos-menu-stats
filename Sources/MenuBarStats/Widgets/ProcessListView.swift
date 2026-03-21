import SwiftUI
import AppKit

/// A single process entry shown in popup process tables.
struct ProcessInfo: Identifiable {
    let id: Int32          // PID
    let name: String
    let value: String      // formatted value (e.g. "23.4%", "2.1 GB")
    let iconImage: NSImage?
}

/// Reusable top-N process list shown in module popups.
struct ProcessListView: View {
    var processes: [ProcessInfo]
    var accentColor: Color
    var maxCount: Int = 5

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(processes.prefix(maxCount).enumerated()), id: \.element.id) { index, proc in
                HStack(spacing: 6) {
                    // App icon
                    if let icon = proc.iconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 16, height: 16)
                    } else {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(accentColor.opacity(0.3))
                            .frame(width: 16, height: 16)
                    }

                    // Process name
                    Text(proc.name)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Value
                    Text(proc.value)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(alignment: .trailing)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(index % 2 == 1 ? Color.primary.opacity(0.04) : Color.clear)
                .cornerRadius(4)
            }
        }
    }
}

// MARK: - Process icon helper

func appIcon(for processName: String) -> NSImage? {
    let ws = NSWorkspace.shared
    // Try to find running app with matching name
    if let app = ws.runningApplications.first(where: {
        $0.localizedName?.lowercased() == processName.lowercased() ||
        $0.bundleIdentifier?.components(separatedBy: ".").last?.lowercased() == processName.lowercased()
    }) {
        return app.icon
    }
    // Fall back to generic executable icon
    return nil
}
