# macos-menu-stats

A lightweight, native macOS menu bar app that displays live system statistics — CPU, memory, disk, network, sensors, and battery — directly in the menu bar. Built entirely in Swift with no third-party dependencies, using only AppKit, SwiftUI, IOKit, and Darwin APIs.

## Features

- **CPU** — total usage, per-core breakdown (P-cores vs E-cores on Apple Silicon), load averages, uptime, top processes
- **Memory** — used/wired/compressed/free RAM, swap usage, memory pressure, top processes
- **Disk** — per-volume capacity and read/write throughput via IOKit
- **Network** — upload/download speed per interface, public IP and local IP
- **Sensors** — CPU and GPU temperatures, fan RPM (via SMC on both Intel and Apple Silicon)
- **Battery** — charge percentage, health, cycle count, time remaining/to full, temperature, voltage, amperage
- **Settings window** — enable/disable any module, adjust update interval (0.5s–10s), choose widget style (text, bar, line graph, or ring), launch at login

Each module shows a compact widget in the menu bar. Clicking a widget opens a popup panel with full details.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15 or later **or** Swift 5.9+ toolchain

No dependencies beyond what ships with macOS.

## Building

### With Xcode

```
open Package.swift
```

Xcode will resolve the package and show the `MenuBarStats` scheme. Press **Cmd+R** to build and run.

### With Swift Package Manager (command line)

```bash
swift build -c release
```

The compiled binary will be at:

```
.build/release/MenuBarStats
```

Run it directly:

```bash
.build/release/MenuBarStats
```

The app appears only in the menu bar (no Dock icon). To quit, right-click any status item and choose **Quit**.

### Debug build

```bash
swift build
.build/debug/MenuBarStats
```

## Project Structure

```
Sources/MenuBarStats/
├── App/
│   ├── main.swift              # Entry point — creates NSApplication and AppDelegate
│   └── AppDelegate.swift       # Initializes modules, opens settings, handles login item
├── Core/
│   ├── Module.swift            # SystemModule protocol
│   ├── Reader.swift            # BaseReader<T> — background polling via DispatchSourceTimer
│   ├── Widget.swift            # Widget types and WidgetType enum
│   ├── Popup.swift             # PopupBase — NSPanel + NSHostingController pattern
│   └── Store.swift             # Thin UserDefaults wrapper
├── Modules/
│   ├── CPU/                    # CPUReader, CPUWidget, CPUPopup, CPUModule
│   ├── Memory/                 # MemoryReader, MemoryWidget, MemoryPopup, MemoryModule
│   ├── Disk/                   # DiskReader, DiskWidget, DiskPopup, DiskModule
│   ├── Network/                # NetworkReader, NetworkWidget, NetworkPopup, NetworkModule
│   ├── Sensors/                # SensorsReader, SMCKit, SensorsWidget, SensorsPopup, SensorsModule
│   └── Battery/                # BatteryReader, BatteryWidget, BatteryPopup, BatteryModule
├── Widgets/
│   ├── LineGraphView.swift     # Scrolling line graph (NSView)
│   ├── BarView.swift           # Fill bar (NSView)
│   ├── PieView.swift           # Ring/donut chart (NSView)
│   ├── PopupSection.swift      # Reusable section header for popups
│   └── ProcessListView.swift   # SwiftUI list of top processes
└── Settings/
    ├── SettingsView.swift       # SwiftUI settings UI (sidebar + detail)
    └── SettingsWindowController.swift
Resources/
└── Info.plist                  # LSUIElement=true (agent app), bundle metadata
Package.swift
```

## Architecture

### Module pattern

Each system area is a self-contained module with three parts:

- **Reader** — subclasses `BaseReader<T>` and runs on a background `DispatchQueue`. Overrides `read()` to collect data and calls `publish(_:)` to deliver it to the main thread via the `callback` closure.
- **Widget** — an `NSView` subclass hosted inside an `NSStatusItem`. Receives data from the module and redraws itself (text, bar, graph, or ring).
- **Popup** — an `NSPanel` (`.nonactivatingPanel`) containing an `NSHostingController` with a SwiftUI view. Opens below the status item button when clicked; closes on click-outside or loss of app focus.

The module class wires these three together, owns the `NSStatusItem`, and forwards data from the reader's callback to both the widget and the open popup.

### Threading

Readers run on dedicated `DispatchQueue` instances (QoS `.utility`). All UI updates happen on the main thread via `DispatchQueue.main.async` inside `publish(_:)`. There is no shared mutable state between readers.

### SMC access (Sensors)

Temperature and fan data are read directly from the System Management Controller via IOKit (`IOServiceOpen` on `AppleSMC`). `SMCKit.swift` implements the key-value read protocol used by every open source macOS stats tool. Apple Silicon and Intel use different SMC key names; the reader tries both sets and uses whichever returns a non-zero value.

### Settings persistence

All preferences are stored in `UserDefaults.standard` under the `com.macos-menu-stats.<module-id>.<key>` namespace. The `Store` wrapper provides typed accessors. Settings take effect immediately without requiring a restart.

## Customization

Each module reads its widget type from `UserDefaults` at draw time, so changing the style in Settings updates the menu bar immediately. Available widget styles:

| Style | Description |
|---|---|
| Text | Percentage or value as a number |
| Bar | Horizontal fill bar |
| Graph | Scrolling line graph (60-sample history) |
| Ring | Donut/pie chart |

## Permissions

The app does not request any special entitlements beyond what is available to unsigned binaries:

- IOKit access for disk stats, SMC, and battery (no entitlement required for IOKit from user space)
- `getifaddrs` / `sysctl` / `host_processor_info` are all available without sandboxing
- Network access for the public IP fetch (Network module, optional)

If you sign and sandbox the app, add `com.apple.security.network.client` to your entitlements file for the public IP lookup.

## License

See [LICENSE](LICENSE).
