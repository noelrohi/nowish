import SwiftUI

@main
struct NowishApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Nowish", image: "MenuBarIcon") {
            ContentView(model: delegate.model, openSettings: delegate.openSettings)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = PresenceModel()
    private let updater = UpdaterManager.shared
    private var settings: SettingsWindowController?
    private var terminating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isTesting else { return }
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        NSApp.setActivationPolicy(.accessory)
        model.start()
        updater.start()
        if !model.canShare { openSettings() }
    }

    func openSettings() {
        if settings == nil { settings = SettingsWindowController(model: model) }
        settings?.showWindow(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isTesting else { return .terminateNow }
        guard !terminating else { return .terminateLater }
        terminating = true
        Task {
            await model.stop()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    private var isTesting: Bool { ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil }
}
