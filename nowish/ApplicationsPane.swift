import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum AppFilter: String, CaseIterable {
    case all = "All apps", shared = "Not ignored", ignored = "Ignored"
}

struct ApplicationsPane: View {
    @Bindable var model: PresenceModel
    var edit: (TrackedApp) -> Void
    @State private var search = ""
    @State private var filter = AppFilter.all

    private var apps: [TrackedApp] {
        let saved = (model.preferences.appActivities ?? [:]).values.map(\.app)
        var byID: [String: TrackedApp] = [:]
        for app in saved + model.preferences.ignored + model.runningApps { byID[app.id] = app }
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
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Choose what you share").font(.title2.weight(.semibold))
                        Text("Share an app when it’s frontmost. Edit its emoji, name, and prefix.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button("Add App…", systemImage: "plus", action: chooseApp)
                }
                HStack(spacing: 12) {
                    TextField("Search apps", text: $search)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Search applications")
                    Picker("Show", selection: $filter) {
                        ForEach(AppFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.labelsHidden().frame(width: 150)
                }
            }.padding(20)
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
                    appRow(app)
                        .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            Divider()
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text("Ignored apps clear your activity when frontmost. Turn on sharing in Activity to publish to Roam.")
            }
            .font(.caption).foregroundStyle(.secondary)
            .padding(16)
        }
    }

    private func appRow(_ app: TrackedApp) -> some View {
        let ignored = isIgnored(app)
        let customized = model.preferences.appActivities?[app.id] != nil
        let running = model.runningApps.contains(where: { $0.id == app.id })
        return HStack(spacing: 12) {
            ApplicationIcon(bundleID: app.id)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(app.name).fontWeight(.medium).lineLimit(1)
                    if model.frontmost?.id == app.id {
                        Text("Current").font(.caption2).foregroundStyle(.tint)
                    }
                }
                if let display = model.preferences.display(for: app) {
                    Text("\(display.emoji) \(display.title)")
                        .font(.callout).foregroundStyle(.secondary).lineLimit(1)
                        .help(display.title)
                } else {
                    Text(model.preferences.emptyActivityReason(for: app) ?? "No activity")
                        .font(.callout).foregroundStyle(.secondary).lineLimit(1)
                }
                Text([running ? "Running" : "Not running", customized ? "Custom activity" : "Default activity"].joined(separator: " · "))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Edit…") { edit(app) }
                .accessibilityLabel("Edit \(app.name)")
            Button {
                model.setIgnored(app, ignored: !ignored)
            } label: {
                Text(ignored ? "Un-ignore" : "Ignore")
                    .frame(width: 68)
            }
            .accessibilityLabel("\(ignored ? "Un-ignore" : "Ignore") \(app.name)")
            .help(ignored ? "Allow activity from \(app.name)" : "Ignore activity from \(app.name)")
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
              let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return }
        edit(TrackedApp(id: id, name: (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? url.deletingPathExtension().lastPathComponent))
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
        .frame(width: 36, height: 36)
        .accessibilityHidden(true)
        .task(id: bundleID) {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                icon = NSWorkspace.shared.icon(forFile: url.path)
            }
        }
    }
}
