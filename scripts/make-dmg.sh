#!/bin/bash
# Local distribution only; the Mac App Store uses Archive/Export instead.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -d build/PegNest.app ] || scripts/build-app.sh release
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp -R build/PegNest.app "$WORK/"
ln -s /Applications "$WORK/Applications"
hdiutil create -volname PegNest -srcfolder "$WORK" -ov -format UDZO build/PegNest.dmg
