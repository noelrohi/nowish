import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum AppFilter: String, CaseIterable {
    case all = "All", shared = "Shared", ignored = "Ignored"
}

struct ApplicationsPane: View {
    @Bindable var model: PresenceModel
    var edit: (TrackedApp) -> Void
    @State private var search = ""
    @State private var filter = AppFilter.all

    private var apps: [TrackedApp] {
        let saved = (model.preferences.appActivities ?? [:]).values.map(\.app)
        var byID: [String: TrackedApp] = [:]
        // Entries saved before Nowish filtered itself can still name a Nowish build.
        for app in saved + model.preferences.ignored + model.runningApps where !PresenceModel.isNowish(app.id) { byID[app.id] = app }
        return byID.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var visibleApps: [TrackedApp] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return apps.filter { app in
            let ignored = isIgnored(app)
            let matchesFilter = filter == .all || (filter == .ignored ? ignored : !ignored)
            let alias = model.preferences.appActivities?[app.id]?.displayName ?? ""
            return matchesFilter && (query.isEmpty || app.name.localizedStandardContains(query) || alias.localizedStandardContains(query))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TextField("Search apps", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Search applications")
                Picker("Show", selection: $filter) {
                    ForEach(AppFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                Button("Add App…", systemImage: "plus", action: chooseApp)
                    .labelStyle(.iconOnly)
                    .help("Add an app")
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            Divider()
            if visibleApps.isEmpty {
                ContentUnavailableView {
                    Label(search.isEmpty ? "No apps here yet" : "No matching apps", systemImage: "app.dashed")
                } description: {
                    Text(search.isEmpty ? "Choose another filter or add an application." : "Try a different name or filter.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(visibleApps) { app in
                    AppRow(model: model, app: app, ignored: isIgnored(app)) { edit(app) }
                        .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            if !model.preferences.sharing {
                Divider()
                Label("Sharing is off. Turn it on in Activity to publish to Roam.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.vertical, 10)
            }
        }
    }

    private func isIgnored(_ app: TrackedApp) -> Bool {
        model.preferences.ignored.contains { $0.id == app.id }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url,
              let bundle = Bundle(url: url), let id = bundle.bundleIdentifier, !PresenceModel.isNowish(id) else { return }
        edit(TrackedApp(id: id, name: (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? url.deletingPathExtension().lastPathComponent))
    }
}

private struct AppRow: View {
    @Bindable var model: PresenceModel
    let app: TrackedApp
    let ignored: Bool
    let edit: () -> Void
    @State private var hovering = false

    private var activityText: String {
        guard !ignored else { return "Not shared" }
        guard let display = model.preferences.display(for: app) else { return "No activity" }
        return "\(display.emoji) \(display.title)"
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: edit) {
                HStack(spacing: 12) {
                    ApplicationIcon(bundleID: app.id)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(app.name).fontWeight(.medium).lineLimit(1)
                            if model.frontmost?.id == app.id {
                                Text("Current").font(.caption2.weight(.medium)).foregroundStyle(.tint)
                            }
                        }
                        Text(activityText)
                            .font(.callout).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .opacity(ignored ? 0.6 : 1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                        .opacity(hovering ? 1 : 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(app.name)")
            .accessibilityValue(activityText)
            Toggle("Share \(app.name)", isOn: Binding(get: { !ignored }, set: { model.setIgnored(app, ignored: !$0) }))
                .toggleStyle(.switch).controlSize(.small).labelsHidden()
                .help(ignored ? "\(app.name) clears your activity when frontmost" : "Share activity from \(app.name)")
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(.quaternary.opacity(hovering ? 0.6 : 0), in: RoundedRectangle(cornerRadius: 8))
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Edit…", action: edit)
            Button(ignored ? "Share" : "Ignore") { model.setIgnored(app, ignored: !ignored) }
        }
    }
}

private struct ApplicationIcon: View {
    let bundleID: String
    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon { Image(nsImage: icon).resizable() }
            else { Image(systemName: "app").resizable().foregroundStyle(.secondary) }
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
        .task(id: bundleID) {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                icon = NSWorkspace.shared.icon(forFile: url.path)
            }
        }
    }
}
