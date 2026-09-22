import AppKit
import Observation

@MainActor @Observable
final class PresenceModel {
    var preferences: Preferences {
        didSet {
            if let data = try? JSONEncoder().encode(preferences) { defaults.set(data, forKey: "preferences") }
            schedule()
        }
    }
    private(set) var runningApps: [TrackedApp] = []
    private(set) var frontmost: TrackedApp?
    private(set) var hasToken = false
    private(set) var error: String?
    private(set) var lastPublished: Date?
    private var token = ""
    private let defaults: UserDefaults
    private let client: RoamClient
    private let externalID: String
    private var observers: [NSObjectProtocol] = []
    private var heartbeat: Task<Void, Never>?
    private var debounce: Task<Void, Never>?
    private var worker: Task<Void, Never>?
    private var dirty = false
    private var suspended = false
    private var stopping = false
    private var publishedUser: String?
    private var publishedToken: String?

    var preview: ActivityDisplay? { preferences.display(for: frontmost) }
    var emptyActivityReason: String? { preferences.emptyActivityReason(for: frontmost) }

    // Derived from current state so the switch and the status never disagree while a request is in flight.
    var status: String {
        if error != nil { return "Couldn’t update Roam" }
        if !preferences.sharing { return "Sharing is off" }
        if !canShare { return "Connect to Roam to start" }
        if suspended { return "Paused while away" }
        if preview == nil { return emptyActivityReason ?? "Activity cleared" }
        return "Sharing with Roam"
    }
    var canShare: Bool { hasToken && !preferences.userID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    init(defaults: UserDefaults = .standard, client: RoamClient? = nil) {
        self.defaults = defaults
        self.client = client ?? RoamClient()
        var loaded = defaults.data(forKey: "preferences").flatMap { try? JSONDecoder().decode(Preferences.self, from: $0) } ?? Preferences()
        if !defaults.bool(forKey: "finderDefaultApplied") {
            if !loaded.ignored.contains(where: { $0.id == Preferences.finder.id }) {
                loaded.ignored.append(Preferences.finder)
            }
            if let data = try? JSONEncoder().encode(loaded) {
                defaults.set(data, forKey: "preferences")
                defaults.set(true, forKey: "finderDefaultApplied")
            }
        }
        preferences = loaded
        externalID = defaults.string(forKey: "externalID") ?? "nowish:\(UUID().uuidString)"
        defaults.set(externalID, forKey: "externalID")
    }

    func start() {
        guard heartbeat == nil else { return }
        do { token = try TokenStore.read(); hasToken = !token.isEmpty }
        catch { self.error = error.localizedDescription }
        refreshApps()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refreshApps() }
            })
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.suspended = true; self?.schedule(immediate: true) }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.suspended = false; self?.refreshApps() }
            })
        }
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                if self?.debounce == nil { self?.enqueue() }
            }
        }
        schedule(immediate: true)
    }

    func saveConnection(userID: String, newToken: String) {
        do {
            if !newToken.isEmpty {
                try TokenStore.save(newToken.trimmingCharacters(in: .whitespacesAndNewlines))
                token = newToken.trimmingCharacters(in: .whitespacesAndNewlines)
                hasToken = !token.isEmpty
            }
            preferences.userID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
            error = nil
            schedule(immediate: true)
        } catch { self.error = error.localizedDescription }
    }

    func setIgnored(_ app: TrackedApp, ignored: Bool) {
        preferences.ignored.removeAll { $0.id == app.id }
        if ignored { preferences.ignored.append(app) }
        schedule(immediate: true)
    }

    func retry() { schedule(immediate: true) }

    func stop() async {
        stopping = true
        heartbeat?.cancel()
        debounce?.cancel()
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
        enqueue()
        await worker?.value
    }

    private func refreshApps() {
        runningApps = NSWorkspace.shared.runningApplications.compactMap { app -> TrackedApp? in
            guard app.activationPolicy == .regular, let id = app.bundleIdentifier,
                  id != Bundle.main.bundleIdentifier else { return nil }
            return TrackedApp(id: id, name: app.localizedName ?? id)
        }.reduce(into: [TrackedApp]()) { result, app in
            if !result.contains(where: { $0.id == app.id }) { result.append(app) }
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        if let app = NSWorkspace.shared.frontmostApplication {
            if app.bundleIdentifier != Bundle.main.bundleIdentifier {
                frontmost = app.bundleIdentifier.map { TrackedApp(id: $0, name: app.localizedName ?? $0) }
            }
        } else {
            frontmost = nil
        }
        schedule(immediate: preview == nil)
    }

    private func schedule(immediate: Bool = false) {
        debounce?.cancel()
        debounce = nil
        if immediate || !preferences.sharing { enqueue(); return }
        debounce = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            self?.debounce = nil
            self?.enqueue()
        }
    }

    // One request at a time: a late set can never overtake a subsequent clear.
    private func enqueue() {
        dirty = true
        guard worker == nil else { return }
        worker = Task { [weak self] in
            guard let self else { return }
            while dirty {
                dirty = false
                await reconcile()
            }
            worker = nil
        }
    }

    private func reconcile() async {
        let user = preferences.userID
        let currentToken = token
        let desired = preferences.sharing && canShare && !suspended && !stopping ? preview : nil
        do {
            if let oldUser = publishedUser, let oldToken = publishedToken,
               oldUser != user || oldToken != currentToken || desired == nil {
                try await client.publish(nil, userID: oldUser, token: oldToken, externalID: externalID)
                publishedUser = nil
                publishedToken = nil
            }
            if let desired {
                // Remember attempted writes too: a lost response may still have reached Roam.
                publishedUser = user
                publishedToken = currentToken
                try await client.publish(desired, userID: user, token: currentToken, externalID: externalID)
                lastPublished = .now
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
