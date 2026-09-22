import SwiftUI

struct UpdatesPane: View {
    @ObservedObject private var updater = UpdaterManager.shared

    var body: some View {
        Form {
            Section("Nowish") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                LabeledContent("Build", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—")
            }
            Section("Software updates") {
                Toggle("Automatically check for updates", isOn: Binding(
                    get: { updater.automaticChecks },
                    set: { updater.setAutomaticChecks($0) }
                ))
                .disabled(!updater.isStarted)
                Button("Check for Updates…", action: updater.checkForUpdates)
                    .disabled(!updater.isStarted || !updater.canCheckForUpdates)
                Text(updater.status).font(.caption).foregroundStyle(.secondary)
                Text("You’ll be asked before an update is installed.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }
}
