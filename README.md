# Nowish

Your status, in the moment. A native macOS menu bar app that shares your frontmost application as a Roam external activity.

## Run

Open `nowish.xcodeproj`, select the `nowish` scheme, and run on macOS 14 or newer. Settings opens on first launch; afterward use the dotted-circle menu bar icon.

1. Open **Settings → Roam** and enter your Roam email (or user ID) and personal access token.
2. Save the connection. The token is stored in macOS Keychain; preferences stay in UserDefaults.
3. Choose an activity text preset, emoji, and optional glow under **Activity**.
4. Under **Applications**, use **Ignore** or **Un-ignore** beside each app. Ignored apps clear activity when frontmost. Finder is ignored by default (applied once to existing settings); you can un-ignore it. Search and filters help find running or saved apps.
5. Use **Applications → Edit…** to set an app’s emoji, prefix, optional display name, and glow color (for example, “🛠️ Building in Xcode”). Leave the display name blank to use the original app name. **Glow → Use default** inherits the global color; **None** disables glow for that app. An empty prefix shows just the name; **Use Defaults** removes the override. **Add App…** lets you configure an app that is not running. Ignored apps remain ignored.
6. Turn on **Share my frontmost app**. Sharing starts off on a fresh installation.

Nowish observes NSWorkspace activation, launch, and termination notifications. It does not inspect window titles, documents, screen contents, or models inside other apps. Opening Nowish retains the last observed app. Apps without a bundle identifier produce no activity.

App switches settle for two seconds before publishing. Ignored apps clear activity immediately. Pause, sleep, session deactivation, and quit also request a clear. Updates heartbeat every 30 seconds and expire after 120 seconds if requests stop reaching Roam. Failed requests retry on the next heartbeat. The menu shows publishing errors. Quit waits for pending requests and a best-effort clear (each request has a 15-second timeout).

Each installation keeps a stable `nowish:<UUID>` external ID. Nowish changes only its own activity row. Existing Claude/Codex hooks and native Roam indicators are independent. It does not change personal status or enable DND.

API contract: [Roam external activity guide](https://developer.ro.am/docs/guides/user-activity.md).

## Verify

```sh
xcodebuild build -project nowish.xcodeproj -scheme nowish -destination 'platform=macOS'
xcodebuild test -project nowish.xcodeproj -scheme nowish -destination 'platform=macOS' -only-testing:nowishTests
```

Unit tests cover presets, ignore rules, Unicode limits, request payloads, and preference persistence. Live Roam delivery needs a user-supplied token. No token is included in the repository.

For a manual check, connect and enable sharing, switch between two apps, ignore one, then pause and resume. Confirm the corresponding activity appears and clears in Roam. Test sleep/wake and quit as well. Sparkle and the release pipeline are configured. Publishing requires the notarization and CI credentials described in [the release guide](docs/releases.md).

## Automatic updates

Sparkle 2.10 is integrated through Swift Package Manager. **Settings → Updates** and the menu bar offer **Check for Updates…**. Automatic checks are available in Release builds; installation remains a user choice. Debug builds never start the updater.

- Public repository: https://github.com/noelrohi/nowish
- Live feed: https://raw.githubusercontent.com/noelrohi/nowish/main/appcast.xml
- Build settings: `NOWISH_UPDATE_FEED_URL` and `NOWISH_UPDATE_PUBLIC_KEY`.
- The private Ed25519 key stays in Keychain under Sparkle account `com.enru.nowish.sparkle`. It is not in the repo. Pass `--account com.enru.nowish.sparkle` to Sparkle signing tools.
- `Configuration/Info.plist` enables the installer service. `nowish.entitlements` allows the sandboxed app to communicate with it. Network access is already needed for Roam, so Sparkle’s downloader service is not enabled.

The public repository hosts the app source, update feed, and release workflow. See [release setup and commands](docs/releases.md).

For a release, archive/export and notarize the app, package it, sign the archive with Sparkle’s `sign_update --account com.enru.nowish.sparkle`, and publish the archive as a GitHub release. Add its download URL, signature, byte length, build number, version, and minimum macOS version to `appcast.xml`. Increment `CURRENT_PROJECT_VERSION` for every update. Publish the matching feed to `main`. Never commit or export the private signing key into source control.

Verified: Debug build and unit tests, Release build, packaged sandbox entitlements/framework, HTTPS feed retrieval, and a live manual Release check returning “You’re up to date.” Download/install and notarized distribution still need the first signed release.
