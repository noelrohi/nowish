#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your notarytool Keychain profile name}"
RELEASE_DIR="${RELEASE_DIR:-$PWD/dist}"
DERIVED_DATA="${DERIVED_DATA:-$PWD/build/DerivedData}"
APP="$RELEASE_DIR/export/nowish.app"
SPARKLE_BIN="$DERIVED_DATA/SourcePackages/artifacts/sparkle/Sparkle/bin"
PROFILE_ARGS=(--keychain-profile "$NOTARY_PROFILE")
if [[ -n "${NOTARY_KEYCHAIN:-}" ]]; then PROFILE_ARGS+=(--keychain "$NOTARY_KEYCHAIN"); fi
submit() {
  xcrun notarytool submit "$1" "${PROFILE_ARGS[@]}" --wait --output-format json > "$2"
  python3 - "$2" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
print('Notarization:',r.get('status'),r.get('id'))
if r.get('status')!='Accepted':
    sys.exit('Notarization failed. Inspect the submission log with notarytool log before publishing.')
PY
}
[[ -d "$APP" ]] || { echo 'Run scripts/build-release.sh first.' >&2; exit 1; }
ditto -c -k --keepParent "$APP" "$RELEASE_DIR/notarization.zip"
submit "$RELEASE_DIR/notarization.zip" "$RELEASE_DIR/app-notarization.json"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
mkdir -p "$RELEASE_DIR/dmg-content"
ditto "$APP" "$RELEASE_DIR/dmg-content/Nowish.app"
ln -sfn /Applications "$RELEASE_DIR/dmg-content/Applications"
hdiutil create -volname Nowish -srcfolder "$RELEASE_DIR/dmg-content" -ov -format UDZO "$RELEASE_DIR/Nowish.dmg"
if [[ -z "${SIGNING_IDENTITY:-}" ]]; then
  codesign -d --extract-certificates="$RELEASE_DIR/signer-" "$APP"
  SIGNING_IDENTITY=$(shasum -a 1 "$RELEASE_DIR/signer-0" | awk '{print $1}')
fi
codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$RELEASE_DIR/Nowish.dmg"
submit "$RELEASE_DIR/Nowish.dmg" "$RELEASE_DIR/dmg-notarization.json"
xcrun stapler staple "$RELEASE_DIR/Nowish.dmg"
xcrun stapler validate "$RELEASE_DIR/Nowish.dmg"
"$SPARKLE_BIN/sign_update" --account com.enru.nowish.sparkle "$RELEASE_DIR/Nowish.dmg" > "$RELEASE_DIR/sparkle-signature.txt"
(cd "$RELEASE_DIR" && shasum -a 256 Nowish.dmg) > "$RELEASE_DIR/SHA256SUMS"
echo "Ready to publish: $RELEASE_DIR/Nowish.dmg"
