#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DEVELOPMENT_TEAM:?Set your actual Apple developer team}"
python3 - "$DEVELOPMENT_TEAM" <<'PY'
import plistlib,sys
from pathlib import Path
p=Path('build/ExportOptions-AppStore.plist')
p.write_bytes(plistlib.dumps(dict(method='app-store-connect',teamID=sys.argv[1],signingStyle='automatic',destination='export')))
PY
xcodebuild -exportArchive -archivePath build/PegNest.xcarchive -exportPath build/AppStore -exportOptionsPlist build/ExportOptions-AppStore.plist
