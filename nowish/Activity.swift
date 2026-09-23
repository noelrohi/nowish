import Foundation

struct TrackedApp: Identifiable, Equatable, Codable {
    let id: String
    let name: String
}

enum TextPreset: String, CaseIterable, Codable {
    case appName = "App name only"
    case working = "Working with…"
    case custom = "Custom text"
}

struct AppActivity: Codable, Equatable {
    var app: TrackedApp
    var emoji: String
    var prefix: String
    var displayName: String? = nil
    // nil inherits the default; an empty string explicitly disables glow.
    var color: String? = nil
    // nil or empty inherits the default subtitle.
    var subtitle: String? = nil

    func title(appName: String) -> String {
        // Reserve room for the app name within Roam's 140-code-point limit.
        let override = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedName = override.isEmpty ? appName : override
        let name = String(String.UnicodeScalarView(resolvedName.unicodeScalars.prefix(140)))
        let available = max(0, 140 - name.unicodeScalars.count - 1)
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = String(String.UnicodeScalarView(trimmed.unicodeScalars.prefix(available)))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return prefix.isEmpty ? name : "\(prefix) \(name)"
    }
}

struct Preferences: Codable, Equatable {
    static let finder = TrackedApp(id: "com.apple.finder", name: "Finder")
    var sharing = false
    var userID = ""
    var preset = TextPreset.appName
    var template = "Working with {app}"
    var emoji = "💻"
    var color = ""
    var ignored: [TrackedApp] = [Self.finder]
    // Optional so preferences saved before per-app activities still decode.
    var appActivities: [String: AppActivity]?
    var subtitle: String?

    func emptyActivityReason(for app: TrackedApp?) -> String? {
        guard let app else { return "Switch to an app to preview its activity" }
        if ignored.contains(where: { $0.id == app.id }) { return "\(app.name) is ignored" }
        if display(for: app) == nil { return "Enter activity text to share" }
        return nil
    }

    func display(for app: TrackedApp?) -> ActivityDisplay? {
        guard let app, !ignored.contains(where: { $0.id == app.id }) else { return nil }
        if let activity = appActivities?[app.id] {
            let resolvedColor = activity.color ?? color
            let override = activity.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return ActivityDisplay(emoji: activity.emoji, title: activity.title(appName: app.name), subtitle: Self.subtitle(override.isEmpty ? subtitle : override, app: app), color: resolvedColor.isEmpty ? nil : resolvedColor)
        }
        let title: String
        switch preset {
        case .appName: title = app.name
        case .working: title = "Working with \(app.name)"
        case .custom: title = template.replacingOccurrences(of: "{app}", with: app.name)
        }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return ActivityDisplay(emoji: emoji, title: String(String.UnicodeScalarView(title.unicodeScalars.prefix(140))), subtitle: Self.subtitle(subtitle, app: app), color: color.isEmpty ? nil : color)
    }

    static func subtitle(_ template: String?, app: TrackedApp) -> String? {
        let text = (template ?? "").replacingOccurrences(of: "{app}", with: app.name).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : String(String.UnicodeScalarView(text.unicodeScalars.prefix(140)))
    }
}

struct ActivityDisplay: Codable, Equatable {
    let emoji: String
    let title: String
    var subtitle: String? = nil
    let color: String?
}

struct ActivityRequest: Encodable {
    let userId: String
    let externalId: String
    let display: ActivityDisplay?
    var ttlSeconds: Int? { display == nil ? nil : 120 }

    enum CodingKeys: CodingKey { case userId, externalId, display, ttlSeconds }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(externalId, forKey: .externalId)
        try container.encodeIfPresent(display, forKey: .display)
        try container.encodeIfPresent(ttlSeconds, forKey: .ttlSeconds)
    }
}

struct RoamClient {
    var session = URLSession.shared

    func publish(_ display: ActivityDisplay?, userID: String, token: String, externalID: String) async throws {
        let action = display == nil ? "clear" : "set"
        var request = URLRequest(url: URL(string: "https://api.ro.am/v1/user.activity.\(action)")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ActivityRequest(userId: userID, externalId: externalID, display: display))
        let (_, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(response.statusCode) else {
            throw RoamError(status: response.statusCode)
        }
    }
}

struct RoamError: LocalizedError {
    let status: Int
    var errorDescription: String? {
        switch status {
        case 401: "Roam rejected the token. Check your personal access token."
        case 403: "This token cannot update that user. Use the token owner’s email."
        case 404: "Roam could not find that user. Check your email or user ID."
        case 429: "Roam is busy. Nowish will retry in 30 seconds."
        default: "Roam returned HTTP \(status). Check your connection settings."
        }
    }
}
