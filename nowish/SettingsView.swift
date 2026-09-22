import SwiftUI
import UniformTypeIdentifiers

private enum SettingsTab: String, CaseIterable, Identifiable {
    case activity = "Activity", applications = "Applications", connection = "Roam", updates = "Updates"
    var id: Self { self }
    var icon: String {
        switch self {
        case .activity: "waveform.path"
        case .applications: "app.badge"
        case .connection: "link"
        case .updates: "arrow.down.circle"
        }
    }
}

struct SettingsView: View {
    @Bindable var model: PresenceModel
    @State private var editingApp: TrackedApp?
    @State private var selection: SettingsTab? = .activity
    @State private var history: [SettingsTab] = [.activity]
    @State private var historyIndex = 0
    @State private var navigatingHistory = false

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(selection: $selection) {
                ForEach(SettingsTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .listStyle(.sidebar)
            .softScrollEdges()
            .navigationTitle("Settings")
            .navigationSplitViewColumnWidth(min: 175, ideal: 175, max: 175)
            .toolbar(removing: .sidebarToggle)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Nowish").font(.headline)
                    Text("Your status, in the moment.").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
            }
        } detail: {
            Group {
                switch selection ?? .activity {
                case .activity: activityPane
                case .applications: ApplicationsPane(model: model) { editingApp = $0 }
                case .connection: ConnectionPane(model: model)
                case .updates: UpdatesPane()
                }
            }
            .navigationTitle((selection ?? .activity).rawValue)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { navigate(-1) } label: { Image(systemName: "chevron.left") }
                    .disabled(historyIndex == 0).help("Back")
                Button { navigate(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(historyIndex == history.count - 1).help("Forward")
            }
        }
        .sheet(item: $editingApp) { app in
            AppActivityEditor(model: model, app: app)
        }
        .onChange(of: selection) { _, tab in
            if navigatingHistory { navigatingHistory = false; return }
            guard let tab else { return }
            history = Array(history.prefix(historyIndex + 1)) + [tab]
            historyIndex = history.count - 1
        }
    }

    private func navigate(_ offset: Int) {
        navigatingHistory = true
        historyIndex += offset
        selection = history[historyIndex]
    }

    private var activityPane: some View {
        Form {
            Section {
                ActivityPreview(display: model.preview, emptyReason: model.emptyActivityReason)
                Toggle("Share my frontmost app", isOn: $model.preferences.sharing)
                    .disabled(!model.canShare)
                Text(model.canShare ? model.status : "Add your personal access token in Roam settings to start sharing.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Activity text") {
                Picker("Preset", selection: $model.preferences.preset) {
                    ForEach(TextPreset.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                if model.preferences.preset == .custom {
                    TextField("Template", text: $model.preferences.template)
                    Text("Use {app} for the app’s name. Titles are limited to 140 characters.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                EmojiField(emoji: $model.preferences.emoji)
                Picker("Glow", selection: $model.preferences.color) {
                    Text("None").tag("")
                    ForEach(["blue", "gold", "gray", "green", "indigo", "lime", "orange", "pink", "purple", "red", "teal", "yellow"], id: \.self) {
                        Text($0.capitalized).tag($0)
                    }
                }
            }
            Section("Follows your focus") {
                Text("Nowish shares the app receiving keyboard input after a two-second delay. Opening Nowish keeps the previous app selected.")
                Text("Ignored apps, pausing, and sleep clear your activity. If Nowish loses its connection, the activity expires within two minutes of the last update.")
            }.font(.callout).foregroundStyle(.secondary)
        }.settingsForm()
    }


}

private struct AppActivityEditor: View {
    @Bindable var model: PresenceModel
    let app: TrackedApp
    @Environment(\.dismiss) private var dismiss
    @State private var emoji: String
    @State private var prefix: String
    @State private var shareApp: Bool
    @State private var color: String?
    @State private var displayName: String

    init(model: PresenceModel, app: TrackedApp) {
        self.model = model
        self.app = app
        _shareApp = State(initialValue: !model.preferences.ignored.contains(where: { $0.id == app.id }))
        let activity = model.preferences.appActivities?[app.id]
        _emoji = State(initialValue: activity?.emoji ?? model.preferences.emoji)
        _displayName = State(initialValue: activity?.displayName ?? "")
        _color = State(initialValue: activity?.color)
        let defaultPrefix: String
        switch model.preferences.preset {
        case .appName: defaultPrefix = ""
        case .working: defaultPrefix = "Working with"
        case .custom: defaultPrefix = model.preferences.template.replacingOccurrences(of: "{app}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        _prefix = State(initialValue: activity?.prefix ?? defaultPrefix)
    }

    private var activity: AppActivity { AppActivity(app: app, emoji: emoji, prefix: prefix, displayName: displayName, color: color) }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section(app.name) {
                    Toggle("Share when this app is frontmost", isOn: $shareApp)
                        .toggleStyle(.switch)
                    EmojiField(emoji: $emoji)
                    Picker("Glow", selection: $color) {
                        Text("Use default").tag(nil as String?)
                        Text("None").tag(Optional(""))
                        ForEach(["blue", "gold", "gray", "green", "indigo", "lime", "orange", "pink", "purple", "red", "teal", "yellow"], id: \.self) {
                            Text($0.capitalized).tag(Optional($0))
                        }
                    }
                    TextField("Display name", text: $displayName, prompt: Text(app.name))
                    TextField("Prefix", text: $prefix, prompt: Text("Working with"))
                    Text("Leave the display name empty to use the original app name. Leave the prefix empty to show just the name.")
                        .font(.caption).foregroundStyle(.secondary)
                    ActivityPreview(display: ActivityDisplay(emoji: emoji, title: activity.title(appName: app.name), color: nil), emptyReason: nil)
                    if !shareApp {
                        Text("Sharing is off for this app. Its activity settings will still be saved.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }.settingsForm()
            HStack {
                Button("Use Defaults") {
                    model.preferences.appActivities?.removeValue(forKey: app.id)
                    dismiss()
                }.disabled(model.preferences.appActivities?[app.id] == nil)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    var activities = model.preferences.appActivities ?? [:]
                    activities[app.id] = activity
                    model.preferences.appActivities = activities
                    model.setIgnored(app, ignored: !shareApp)
                    dismiss()
                }.keyboardShortcut(.defaultAction)
            }.padding(20)
        }.frame(width: 500, height: 550)
    }
}

private struct ConnectionPane: View {
    @Bindable var model: PresenceModel
    @State private var userID = ""
    @State private var token = ""
    @State private var saved = false

    var body: some View {
        Form {
            Section("Connect to Roam") {
                Text("Use your own Roam email and personal access token. Your token is stored in macOS Keychain.")
                    .foregroundStyle(.secondary)
                TextField("Email or user ID", text: $userID)
                    .autocorrectionDisabled()
                SecureField(model.hasToken ? "Replace saved token" : "Personal access token", text: $token)
                HStack {
                    Button("Save Connection") {
                        model.saveConnection(userID: userID, newToken: token)
                        token = ""
                        saved = model.error == nil
                    }.disabled(userID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (!model.hasToken && token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    if saved { Text("Saved").font(.caption).foregroundStyle(.secondary) }
                }
                Link("Roam activity API guide", destination: URL(string: "https://developer.ro.am/docs/guides/user-activity")!)
            }
            Section("Connection status") {
                LabeledContent("Token", value: model.hasToken ? "Stored in Keychain" : "Not configured")
                Text(model.status).foregroundStyle(.secondary)
                if let date = model.lastPublished {
                    LabeledContent("Last published") { Text(date, style: .time) }
                }
                if let error = model.error {
                    Text(error).foregroundStyle(.orange)
                    Button("Retry", action: model.retry)
                }
                Text("Saving does not turn sharing on. Enable sharing in Activity when you’re ready.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .settingsForm()
        .onAppear { userID = model.preferences.userID }
        .onChange(of: userID) { saved = false }

    }
}

private extension View {
    func settingsForm() -> some View {
        formStyle(.grouped).scrollContentBackground(.hidden).contentMargins(.top, 8, for: .scrollContent)
    }

    @ViewBuilder func softScrollEdges() -> some View {
        if #available(macOS 26.0, *) { scrollEdgeEffectStyle(.soft, for: .all) }
        else { self }
    }
}
