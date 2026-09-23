# Shipping Nowish

The app is distributed through GitHub Releases at https://github.com/noelrohi/nowish. Sparkle reads `appcast.xml` on `main`. Never advertise a download or update before its notarized artifact is public.

## First-time setup

Run `./scripts/setup-release-wizard.sh` from the repository. Stage 1 reuses or creates a local notarization Keychain profile. The optional remaining stages configure GitHub Actions secrets:

- `APPLE_CERTIFICATE_BASE64`: Developer ID Application certificate and private key exported as password-protected .p12, base64 encoded.
- `APPLE_CERTIFICATE_PASSWORD`: export password.
- `APPLE_ID` and `APPLE_APP_SPECIFIC_PASSWORD`: notarization account in Apple team `2Z79866758`.
- `SPARKLE_PRIVATE_KEY`: existing Keychain signing key for account `com.enru.nowish.sparkle`.

The wizard never prints private keys or passwords. `.env.release` stores only local setup metadata, is mode 600, and is ignored by Git. Keep the .p12 outside the repository. Existing notarytool profiles are local to their Keychain; runners still need their own secrets.

## Local release

Increment `MARKETING_VERSION` (three components, e.g. `1.0.0`) and `CURRENT_PROJECT_VERSION` in Xcode before archiving. Build numbers must increase.

Write `release-notes/VERSION.md` for every release. Sparkle shows these notes in the update window, and GitHub uses them as the release body. Use short paragraphs and `- ` bullets; backticks become code. Releases without notes are refused.

```sh
scripts/build-release.sh
NOTARY_PROFILE=your-profile scripts/notarize-release.sh
python3 scripts/prepare-appcast.py
```

`RELEASE_DIR` (default `dist`) and `DERIVED_DATA` (default `build/DerivedData`) may be overridden. For a profile in a custom Keychain, also pass `NOTARY_KEYCHAIN`.

The build is universal (Apple silicon and Intel). Export uses Developer ID; verification rejects debug entitlements. Notarization submits the app, staples it, builds and signs a DMG with an Applications shortcut, notarizes/staples the DMG, then signs the final DMG for Sparkle. Do not modify it after signing.

Publish `dist/Nowish.dmg` and `dist/SHA256SUMS` to a GitHub release tagged with the matching `vVERSION`, then commit/push `appcast.xml` and `site/release.json` to `main`. The release tag must point at the actual source used to archive the app.

After publishing, redeploy the marketing site:

```sh
npx wrangler@4 pages deploy site --project-name nowish --branch main --commit-dirty=true
```

## GitHub Actions

The **Release Nowish** workflow is manually dispatched on `main`, with the version already configured in Xcode. It creates an isolated signing Keychain, runs unit tests, archives/exports, notarizes, packages, Sparkle-signs, publishes GitHub release assets, and commits the updated feed and website metadata. The workflow intentionally does not have access to Cloudflare credentials; redeploy Pages with the command above after it finishes.

Use a new version/build for each run. If publishing succeeds but pushing metadata fails, repair the metadata commit for the existing artifact; do not rebuild and overwrite an already published version. The workflow refuses to overwrite an existing release.

## Verification

Before calling a release done, check Developer ID signature, both CPU architectures, notarization `Accepted`, staple validation, Gatekeeper acceptance, Sparkle signature, public asset download and checksum, feed URLs, and the live website download button. End-to-end Sparkle replacement can only be tested with an older installed release.
