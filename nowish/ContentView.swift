import SwiftUI

struct ContentView: View {
    @Bindable var model: PresenceModel
    var openSettings: () -> Void

    private var statusColor: Color {
        if model.error != nil { return .orange }
        return model.preferences.sharing && model.canShare ? .green : .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image("MenuBarIcon")
                VStack(alignment: .leading, spacing: 1) {
                    Text("Nowish").font(.headline)
                    HStack(spacing: 5) {
                        Circle().fill(statusColor).frame(width: 6, height: 6)
                        Text(model.status).lineLimit(1)
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Share activity", isOn: $model.preferences.sharing)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(!model.canShare)
                    .help("Share your frontmost app with Roam")
            }
            ActivityPreview(display: model.preview, emptyReason: model.emptyActivityReason)
            if let error = model.error {
                HStack(alignment: .firstTextBaseline) {
                    Text(error).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Retry", action: model.retry).controlSize(.small)
                }
            }
            Divider()
            VStack(spacing: 0) {
                if let app = model.frontmost {
                    let ignored = model.preferences.ignored.contains(where: { $0.id == app.id })
                    MenuRow(ignored ? "Share \(app.name)" : "Ignore \(app.name)") {
                        model.setIgnored(app, ignored: !ignored)
                    }
                }
                MenuRow("Settings…", shortcut: "⌘,", action: openSettings).keyboardShortcut(",")
                MenuRow("Quit Nowish", shortcut: "⌘Q") { NSApp.terminate(nil) }.keyboardShortcut("q")
            }
            .padding(.horizontal, -8)
        }
        .padding(16)
        .frame(width: 320)
    }
}

private struct MenuRow: View {
    let title: String
    var shortcut: String?
    let action: () -> Void
    @State private var hovering = false

    init(_ title: String, shortcut: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.shortcut = shortcut
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).lineLimit(1)
                Spacer()
                if let shortcut { Text(shortcut).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(.quaternary.opacity(hovering ? 1 : 0), in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
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
