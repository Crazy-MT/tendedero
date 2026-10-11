#!/bin/bash
# A sandboxed local build. An ad hoc signature is not an App Store signature.
set -euo pipefail
cd "$(dirname "$0")/.."
case "${1:-release}" in debug) CONFIG=Debug;; release) CONFIG=Release;; *) echo 'Usage: scripts/build-app.sh [debug|release]' >&2; exit 2;; esac
mkdir -p build
xcodebuild -project PegNest.xcodeproj -scheme PegNest -configuration "$CONFIG" -derivedDataPath build/DerivedData -destination 'generic/platform=macOS' ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual build > build/xcode-build.log 2>&1 || { tail -80 build/xcode-build.log; exit 1; }
if [ -d build/PegNest.app ]; then rm -rf build/PegNest.app; fi
cp -R "build/DerivedData/Build/Products/$CONFIG/PegNest.app" build/PegNest.app
printf 'Built sandboxed %s\n' "build/PegNest.app"
