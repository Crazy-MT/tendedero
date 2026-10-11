#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="${1:-build/PegNest.app}"
plutil -lint "$APP/Contents/Info.plist" "$APP/Contents/Resources/PrivacyInfo.xcprivacy" Config/PegNest.entitlements
codesign --verify --deep --strict "$APP"
codesign -d --entitlements :- "$APP" 2>/dev/null > build/verified-entitlements.plist
python3 - "$APP" <<'PY'
import plistlib,sys
from pathlib import Path
app=Path(sys.argv[1]); ent=plistlib.loads(Path('build/verified-entitlements.plist').read_bytes())
for key in ['com.apple.security.app-sandbox','com.apple.security.files.user-selected.read-write','com.apple.security.files.bookmarks.app-scope']:assert ent.get(key) is True,key
for key in ['com.apple.security.network.client','com.apple.security.automation.apple-events']:assert not ent.get(key),key
assert (app/'Contents/Resources/LICENSE.txt').read_bytes()==Path('LICENSE').read_bytes()
assert (app/'Contents/Resources/AppIcon.icns').exists()
for lang in ['en','zh-Hans']:assert (app/f'Contents/Resources/{lang}.lproj/Localizable.strings').exists()
print('Sandbox, license, icon and localizations verified')
PY
lipo "$APP/Contents/MacOS/PegNest" -verify_arch arm64 x86_64
if nm -u "$APP/Contents/MacOS/PegNest" | rg 'CGSMainConnectionID|CGSCopyManagedDisplaySpaces'; then echo 'Private API found' >&2; exit 1; fi
printf 'Release structure verified (local ad hoc signature; not a store submission).\n'
