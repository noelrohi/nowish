import SwiftUI

struct ContentView: View {
    @ObservedObject private var updater = UpdaterManager.shared
    @Bindable var model: PresenceModel
    var openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Nowish", image: "MenuBarIcon")
                    .font(.headline)
                Spacer()
                Toggle("Share activity", isOn: $model.preferences.sharing)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(!model.canShare)
                    .help("Share your frontmost app with Roam")
            }
            ActivityPreview(display: model.preview, emptyReason: model.emptyActivityReason)
            VStack(alignment: .leading, spacing: 5) {
                Label(model.status, systemImage: model.error == nil ? "circle.fill" : "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(model.error == nil ? Color.secondary : Color.orange)
                if let error = model.error {
                    Text(error).font(.caption).foregroundStyle(.secondary)
                    Button("Retry", action: model.retry).controlSize(.small)
                }
            }
            if let app = model.frontmost {
                let ignored = model.preferences.ignored.contains(where: { $0.id == app.id })
                Button(ignored ? "Un-ignore \(app.name)" : "Ignore \(app.name)") {
                    model.setIgnored(app, ignored: !ignored)
                }
            }
            Button("Check for Updates…", action: updater.checkForUpdates)
                .disabled(!updater.isStarted || !updater.canCheckForUpdates)
            Divider()
            HStack {
                Button("Settings…", action: openSettings).keyboardShortcut(",")
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(width: 320)
    }
}

struct ActivityPreview: View {
    var display: ActivityDisplay?
    var emptyReason: String?

    var body: some View {
        HStack(spacing: 12) {
            Text(display?.emoji ?? "☾").font(.system(size: 28))
                .frame(width: 44, height: 44)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text("ACTIVITY PREVIEW").font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(1.2).foregroundStyle(.secondary)
                Text(display?.title ?? emptyReason ?? "No activity to share")
                    .font(.headline).lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 16))
    }
}
