#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
RELEASE_DIR="${RELEASE_DIR:-$PWD/dist}"
DERIVED_DATA="${DERIVED_DATA:-$PWD/build/DerivedData}"
mkdir -p "$RELEASE_DIR"
xcodebuild archive -project nowish.xcodeproj -scheme nowish -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$RELEASE_DIR/Nowish.xcarchive" \
  -derivedDataPath "$DERIVED_DATA" ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY='Developer ID Application' \
  DEVELOPMENT_TEAM=2Z79866758
xcodebuild -exportArchive -archivePath "$RELEASE_DIR/Nowish.xcarchive" \
  -exportOptionsPlist Configuration/ExportOptions.plist -exportPath "$RELEASE_DIR/export"
APP="$RELEASE_DIR/export/nowish.app"
codesign --verify --deep --strict "$APP"
python3 - "$APP" <<'PY'
import plistlib,subprocess,sys
from pathlib import Path
app=Path(sys.argv[1])
p=plistlib.loads((app/'Contents/Info.plist').read_bytes())
assert p['SUFeedURL']=='https://raw.githubusercontent.com/noelrohi/nowish/main/appcast.xml'
assert p['SUPublicEDKey']=='ITBjkXjmtfAscYEBVG9Ro/qJ+zTlj1Zx5kaEibbZIp0='
assert p['SUEnableInstallerLauncherService'] is True
archs=subprocess.check_output(['lipo','-archs',str(app/'Contents/MacOS/nowish')],text=True).split()
assert set(archs)=={'arm64','x86_64'},archs
entitlements=plistlib.loads(subprocess.check_output(['codesign','-d','--entitlements',':-',str(app)],stderr=subprocess.DEVNULL))
assert not entitlements.get('com.apple.security.get-task-allow',False)
print('Verified universal architecture, update configuration, and distribution entitlements.')
PY
