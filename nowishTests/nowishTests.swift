import Foundation
import Testing
@testable import nowish

@MainActor
struct NowishTests {
    private let xcode = TrackedApp(id: "com.apple.dt.Xcode", name: "Xcode")

    @Test func acceptsFreeformEmojiAndRejectsTextOrMultipleEmoji() {
        for emoji in ["🦊", "👩‍💻", "🇵🇭", "👍🏽", "1️⃣", "❤️", "©️"] {
            #expect(ActivityEmoji.isValid(emoji))
        }
        for text in ["", "hello", "1", "#", "*", "💻🚀", " 💻", "🏽", "🇵"] {
            #expect(!ActivityEmoji.isValid(text))
        }
    }

    @Test func presetsAndIgnoredApps() {
        var preferences = Preferences()
        #expect(preferences.display(for: xcode)?.title == "Working with Xcode")
        preferences.preset = .appName
        #expect(preferences.display(for: xcode)?.title == "Xcode")
        preferences.preset = .custom
        preferences.template = "Building in {app}"
        #expect(preferences.display(for: xcode)?.title == "Building in Xcode")
        preferences.ignored = [xcode]
        #expect(preferences.display(for: xcode) == nil)
        #expect(preferences.display(for: nil) == nil)
    }

    @Test func emptyPreviewExplainsIgnoredAppAndRecoversWhenRemoved() {
        var preferences = Preferences()
        preferences.ignored = [xcode]
        #expect(preferences.display(for: xcode) == nil)
        #expect(preferences.emptyActivityReason(for: xcode) == "Xcode is ignored")
        preferences.ignored.removeAll()
        #expect(preferences.emptyActivityReason(for: xcode) == nil)
        #expect(preferences.display(for: xcode)?.title == "Working with Xcode")
        #expect(preferences.emptyActivityReason(for: nil) == "Switch to an app to preview its activity")
        preferences.preset = .custom
        preferences.template = " "
        #expect(preferences.emptyActivityReason(for: xcode) == "Enter activity text to share")
    }

    @Test func perAppActivityOverridesDefaultsAndHonorsIgnore() throws {
        var preferences = Preferences()
        preferences.appActivities = [xcode.id: AppActivity(app: xcode, emoji: "🛠️", prefix: "  Building in  ")]
        #expect(preferences.display(for: xcode)?.title == "Building in Xcode")
        #expect(preferences.display(for: xcode)?.emoji == "🛠️")
        let safari = TrackedApp(id: "com.apple.Safari", name: "Safari")
        #expect(preferences.display(for: safari)?.title == "Working with Safari")
        #expect(preferences.display(for: safari)?.emoji == "💻")
        let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences))
        #expect(restored == preferences)
        preferences.appActivities?[xcode.id]?.prefix = " "
        #expect(preferences.display(for: xcode)?.title == "Xcode")
        preferences.appActivities?[xcode.id]?.prefix = String(repeating: "🚀", count: 200)
        let title = try #require(preferences.display(for: xcode)?.title)
        #expect(title.unicodeScalars.count == 140)
        #expect(title.hasSuffix(" Xcode"))
        preferences.ignored = [xcode]
        #expect(preferences.display(for: xcode) == nil)
        preferences.ignored = []
        preferences.appActivities?.removeValue(forKey: xcode.id)
        #expect(preferences.display(for: xcode)?.title == "Working with Xcode")
    }

    @Test func displayNameOverridePersistsAndFallsBackWhenBlank() throws {
        var preferences = Preferences()
        preferences.appActivities = [xcode.id: AppActivity(app: xcode, emoji: "💻", prefix: "Coding in", displayName: "  My IDE  ")]
        #expect(preferences.display(for: xcode)?.title == "Coding in My IDE")
        let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences))
        #expect(restored.display(for: xcode)?.title == "Coding in My IDE")
        preferences.appActivities?[xcode.id]?.displayName = " \n "
        #expect(preferences.display(for: xcode)?.title == "Coding in Xcode")
        preferences.appActivities?[xcode.id]?.displayName = String(repeating: "🚀", count: 150)
        #expect(preferences.display(for: xcode)?.title.unicodeScalars.count == 140)
        preferences.ignored = [xcode]
        #expect(preferences.display(for: xcode) == nil)
        let legacy = Data(#"{"app":{"id":"com.apple.dt.Xcode","name":"Xcode"},"emoji":"💻","prefix":"Using"}"#.utf8)
        let activity = try JSONDecoder().decode(AppActivity.self, from: legacy)
        #expect(activity.displayName == nil)
        #expect(activity.title(appName: "Xcode") == "Using Xcode")
    }

    @Test func perAppGlowInheritsOverridesAndDisables() throws {
        var preferences = Preferences()
        preferences.color = "green"
        preferences.appActivities = [xcode.id: AppActivity(app: xcode, emoji: "💻", prefix: "Using")]
        #expect(preferences.display(for: xcode)?.color == "green")
        preferences.appActivities?[xcode.id]?.color = "purple"
        #expect(preferences.display(for: xcode)?.color == "purple")
        let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences))
        #expect(restored.display(for: xcode)?.color == "purple")
        preferences.appActivities?[xcode.id]?.color = ""
        #expect(preferences.display(for: xcode)?.color == nil)
        preferences.appActivities?[xcode.id]?.color = nil
        preferences.color = "blue"
        #expect(preferences.display(for: xcode)?.color == "blue")
        let legacy = Data(#"{"app":{"id":"com.apple.dt.Xcode","name":"Xcode"},"emoji":"💻","prefix":"Using"}"#.utf8)
        #expect(try JSONDecoder().decode(AppActivity.self, from: legacy).color == nil)
    }

    @Test func existingPreferencesLoadWithoutPerAppSettings() throws {
        let legacy = Data(#"{"sharing":true,"userID":"person@example.com","preset":"App name only","template":"{app}","emoji":"🎨","color":"green","ignored":[{"id":"com.apple.dt.Xcode","name":"Xcode"}]}"#.utf8)
        let preferences = try JSONDecoder().decode(Preferences.self, from: legacy)
        #expect(preferences.sharing)
        #expect(preferences.preset == .appName)
        #expect(preferences.emoji == "🎨")
        #expect(preferences.ignored == [xcode])
        #expect(preferences.appActivities == nil)
    }

    @Test func unicodeLimitsAndBlankTitles() {
        var preferences = Preferences()
        preferences.preset = .custom
        preferences.template = String(repeating: "🚀", count: 150)
        #expect(preferences.display(for: xcode)?.title.unicodeScalars.count == 140)
        preferences.template = " \n "
        #expect(preferences.display(for: xcode) == nil)
    }

    @Test func setAndClearPayloads() throws {
        let display = Preferences().display(for: xcode)
        let set = ActivityRequest(userId: "person@example.com", externalId: "nowish:test", display: display)
        let data = try JSONEncoder().encode(set)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["ttlSeconds"] as? Int == 120)
        #expect(json["externalId"] as? String == "nowish:test")
        let appearance = try #require(json["display"] as? [String: Any])
        #expect(appearance["title"] as? String == "Working with Xcode")
        #expect(appearance["color"] == nil)
        #expect(json["dnd"] == nil)
        let clear = ActivityRequest(userId: "person@example.com", externalId: "nowish:test", display: nil)
        let clearJSON = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(clear)) as? [String: Any])
        #expect(clearJSON.count == 2)
        #expect(clearJSON["display"] == nil)
        #expect(clearJSON["ttlSeconds"] == nil)
    }

    @Test func transportHandlesSetClearAndAuthorizationFailure() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RoamProtocolStub.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = RoamClient(session: session)
        try await client.publish(Preferences().display(for: xcode), userID: "person@example.com", token: "test-token", externalID: "nowish:test")
        try await client.publish(nil, userID: "person@example.com", token: "test-token", externalID: "nowish:test")
        do {
            try await client.publish(nil, userID: "person@example.com", token: "rejected", externalID: "nowish:test")
            Issue.record("A rejected token should throw")
        } catch let error as RoamError {
            #expect(error.status == 403)
        }
    }

    @Test func finderDefaultMigratesOnceAndRespectsUnignore() async throws {
        #expect(Preferences().display(for: Preferences.finder) == nil)
        let suite = "NowishTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var legacy = Preferences()
        legacy.ignored = [xcode]
        defaults.set(try JSONEncoder().encode(legacy), forKey: "preferences")
        let migrated = PresenceModel(defaults: defaults)
        #expect(migrated.preferences.ignored == [xcode, Preferences.finder])
        let reopened = PresenceModel(defaults: defaults)
        #expect(reopened.preferences.ignored == [xcode, Preferences.finder])
        migrated.setIgnored(Preferences.finder, ignored: false)
        let restored = PresenceModel(defaults: defaults)
        #expect(restored.preferences.ignored == [xcode])
        #expect(restored.preferences.display(for: Preferences.finder)?.title == "Working with Finder")
        await migrated.stop()
        await reopened.stop()
        await restored.stop()
    }

    @Test func preferencesPersistWithoutCredentials() async throws {
        let suite = "NowishTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = PresenceModel(defaults: defaults)
        #expect(!model.preferences.sharing)
        model.setIgnored(xcode, ignored: true)
        model.setIgnored(xcode, ignored: true)
        #expect(model.preferences.ignored.count == 2)
        model.preferences.preset = .appName
        let restored = PresenceModel(defaults: defaults)
        #expect(restored.preferences.ignored == [Preferences.finder, xcode])
        #expect(restored.preferences.preset == .appName)
        #expect(!restored.hasToken)
        await model.stop()
        await restored.stop()
    }
}

private final class RoamProtocolStub: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url, url.host == "api.ro.am",
              request.httpMethod == "POST",
              request.value(forHTTPHeaderField: "Content-Type") == "application/json",
              ["/v1/user.activity.set", "/v1/user.activity.clear"].contains(url.path) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let rejected = request.value(forHTTPHeaderField: "Authorization") != "Bearer test-token"
        let status = rejected ? 403 : url.path.hasSuffix("clear") ? 204 : 200
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
