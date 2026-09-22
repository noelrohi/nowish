import AppKit
import Combine
import Sparkle

@MainActor
final class UpdaterManager: NSObject, ObservableObject, SPUStandardUserDriverDelegate {
    static let shared = UpdaterManager()
    private var controller: SPUStandardUpdaterController!
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticChecks = false
    @Published private(set) var isStarted = false
    @Published private(set) var status = "Updates have not started."

    private override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: self)
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates).assign(to: &$automaticChecks)
    }

    func start() {
        #if DEBUG
        status = "Update checks are disabled in development builds."
        #else
        guard !isStarted else { return }
        guard let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let url = URL(string: feed), url.scheme == "https", url.host != nil,
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32 else {
            status = "Updates are not configured for this build."
            return
        }
        do {
            try controller.updater.start()
            isStarted = true
            status = "Updates are delivered securely from Nowish’s release feed."
        } catch {
            status = "Couldn’t start updates: \(error.localizedDescription)"
        }
        #endif
    }

    func setAutomaticChecks(_ enabled: Bool) {
        guard isStarted else { return }
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    func checkForUpdates() {
        guard isStarted, canCheckForUpdates else { return }
        AppActivation.set(.updates, visible: true)
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }

    func standardUserDriverWillShowModalAlert() {
        AppActivation.set(.updates, visible: true)
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        if handleShowingUpdate { AppActivation.set(.updates, visible: true) }
    }

    func standardUserDriverWillFinishUpdateSession() {
        AppActivation.set(.updates, visible: false)
    }
}

@MainActor
enum AppActivation {
    enum Window { case settings, updates }
    private static var windows: Set<Window> = []

    static func set(_ window: Window, visible: Bool) {
        if visible { windows.insert(window) } else { windows.remove(window) }
        NSApp.setActivationPolicy(windows.isEmpty ? .accessory : .regular)
    }
}
