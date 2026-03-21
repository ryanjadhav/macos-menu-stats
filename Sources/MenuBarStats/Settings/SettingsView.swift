import SwiftUI
import ServiceManagement

// MARK: - Module list item model

struct ModuleItem: Identifiable {
    let id: String
    let name: String
    let symbolName: String
    var isEnabled: Bool
}

// MARK: - Main settings view

struct SettingsView: View {
    @State private var items: [ModuleItem]
    @State private var selectedID: String?
    private let modules: [any SystemModule]

    init(modules: [any SystemModule]) {
        self.modules = modules
        _items = State(initialValue: modules.map {
            ModuleItem(
                id: $0.id,
                name: $0.name,
                symbolName: $0.symbolName,
                isEnabled: Store.shared.bool(for: "com.macos-menu-stats.\($0.id).enabled", default: true)
            )
        })
        _selectedID = State(initialValue: modules.first?.id)
    }

    var body: some View {
        NavigationSplitView {
            sidebarList
        } detail: {
            if let id = selectedID,
               let module = modules.first(where: { $0.id == id }),
               let item = items.first(where: { $0.id == id }) {
                ModuleSettingsView(module: module, isEnabled: Binding(
                    get: { item.isEnabled },
                    set: { newVal in toggleModule(id: id, enabled: newVal) }
                ))
            } else {
                Text("Select a module")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 520, minHeight: 400)
    }

    private var sidebarList: some View {
        List(items, selection: $selectedID) { item in
            HStack(spacing: 10) {
                Image(systemName: item.symbolName)
                    .font(.system(size: 14))
                    .foregroundStyle(item.isEnabled ? .primary : .tertiary)
                    .frame(width: 20)
                Text(item.name)
                    .font(.system(size: 13))
                    .foregroundStyle(item.isEnabled ? .primary : .secondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { item.isEnabled },
                    set: { newVal in toggleModule(id: item.id, enabled: newVal) }
                ))
                .labelsHidden()
                .scaleEffect(0.8)
            }
            .contentShape(Rectangle())
            .tag(item.id)
        }
        .listStyle(.sidebar)
        .frame(minWidth: 160)
        .navigationTitle("MenuBar Stats")
    }

    private func toggleModule(id: String, enabled: Bool) {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items[idx].isEnabled = enabled
        }
        Store.shared.set(enabled, for: "com.macos-menu-stats.\(id).enabled")
        if let module = modules.first(where: { $0.id == id }) {
            if enabled { module.enable() } else { module.disable() }
        }
    }
}

// MARK: - Per-module settings panel

struct ModuleSettingsView: View {
    let module: any SystemModule
    @Binding var isEnabled: Bool

    @State private var intervalIndex: Int = 1
    @State private var widgetTypeIndex: Int = 0
    @State private var launchAtLogin: Bool = false

    private static let intervals: [Double] = [0.5, 1.0, 2.0, 5.0, 10.0]
    private static let intervalLabels = ["0.5s", "1s", "2s", "5s", "10s"]

    var body: some View {
        Form {
            Section("General") {
                Toggle("Enabled", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, newVal in
                        if newVal { module.enable() } else { module.disable() }
                    }
            }

            Section("Update Interval") {
                Picker("Interval", selection: $intervalIndex) {
                    ForEach(Array(Self.intervalLabels.enumerated()), id: \.offset) { i, label in
                        Text(label).tag(i)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: intervalIndex) { _, idx in
                    let interval = Self.intervals[idx]
                    module.setUpdateInterval(interval)
                    Store.shared.set(interval, for: "com.macos-menu-stats.\(module.id).interval")
                }
            }

            Section("Widget Style") {
                Picker("Type", selection: $widgetTypeIndex) {
                    Text("Text").tag(0)
                    Text("Bar").tag(1)
                    Text("Graph").tag(2)
                    Text("Ring").tag(3)
                }
                .pickerStyle(.segmented)
                .onChange(of: widgetTypeIndex) { _, idx in
                    let types: [WidgetType] = [.text, .barGraph, .lineGraph, .ring]
                    Store.shared.set(types[idx].rawValue, for: "com.macos-menu-stats.\(module.id).widgetType")
                }
            }

            Section("System") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newVal in
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.setLaunchAtLogin(newVal)
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(module.name)
        .onAppear { loadValues() }
    }

    private func loadValues() {
        let interval = Store.shared.double(for: "com.macos-menu-stats.\(module.id).interval", default: 1.0)
        intervalIndex = Self.intervals.firstIndex(of: interval) ?? 1

        let typeRaw = Store.shared.string(for: "com.macos-menu-stats.\(module.id).widgetType", default: "text")
        let types: [WidgetType] = [.text, .barGraph, .lineGraph, .ring]
        widgetTypeIndex = types.firstIndex { $0.rawValue == typeRaw } ?? 0

        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
