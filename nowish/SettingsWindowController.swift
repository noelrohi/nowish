import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    init(model: PresenceModel) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 590),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "Nowish Settings"
        window.toolbarStyle = .automatic
        window.minSize = NSSize(width: 700, height: 520)
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("NowishSettings")
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: SettingsView(model: model))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func showWindow(_ sender: Any?) {
        AppActivation.set(.settings, visible: true)
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) { AppActivation.set(.settings, visible: false) }
}
