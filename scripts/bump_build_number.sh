#!/usr/bin/env bash
# Bumps the build number (the "+N" in pubspec.yaml's version: X.Y.Z+N).
# iOS reads it via Generated.xcconfig, Android via flutter.versionCode — both
# come from this single pubspec.yaml line, so bumping it here covers both.
#
# Wired into:
#   - ios/Runner.xcodeproj: Runner scheme, Archive pre-action (fires on
#     Product > Archive and on `flutter build ipa`).
#   - android/app/build.gradle.kts: fires on `assembleRelease` / `bundleRelease`
#     (i.e. `flutter build appbundle`/`apk` or Android Studio's signed bundle).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBSPEC="$SCRIPT_DIR/../pubspec.yaml"

CURRENT_VERSION="$(grep -m1 '^version:' "$PUBSPEC" | sed -E 's/^version:[[:space:]]*//')"
VERSION_NAME="${CURRENT_VERSION%%+*}"
BUILD_NUMBER="${CURRENT_VERSION##*+}"

if [[ "$BUILD_NUMBER" == "$CURRENT_VERSION" || -z "$BUILD_NUMBER" ]]; then
  echo "bump_build_number: pubspec.yaml version has no '+N' build number (got '$CURRENT_VERSION')" >&2
  exit 1
fi

NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
NEW_VERSION="${VERSION_NAME}+${NEW_BUILD_NUMBER}"

sed -i '' -E "s/^version:.*/version: ${NEW_VERSION}/" "$PUBSPEC"

echo "bump_build_number: ${CURRENT_VERSION} -> ${NEW_VERSION}"
