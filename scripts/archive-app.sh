#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DEVELOPMENT_TEAM:?Set your actual Apple developer team}"
: "${PRODUCT_BUNDLE_IDENTIFIER:?Set your registered Bundle ID}"
[ "$PRODUCT_BUNDLE_IDENTIFIER" != local.PegNest ] || { echo 'The local Bundle ID cannot be submitted.' >&2; exit 2; }
xcodebuild -project PegNest.xcodeproj -scheme PegNest -configuration Release -destination 'generic/platform=macOS' -archivePath build/PegNest.xcarchive DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" PRODUCT_BUNDLE_IDENTIFIER="$PRODUCT_BUNDLE_IDENTIFIER" CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY='Apple Development' ARCHS='arm64 x86_64' archive
