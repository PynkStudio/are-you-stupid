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
IOS_PROJECT="$SCRIPT_DIR/../ios/Runner.xcodeproj/project.pbxproj"

CURRENT_VERSION="$(grep -m1 '^version:' "$PUBSPEC" | sed -E 's/^version:[[:space:]]*//')"
VERSION_NAME="${CURRENT_VERSION%%+*}"
BUILD_NUMBER="${CURRENT_VERSION##*+}"

if [[ "$BUILD_NUMBER" == "$CURRENT_VERSION" || -z "$BUILD_NUMBER" ]]; then
  echo "bump_build_number: pubspec.yaml version has no '+N' build number (got '$CURRENT_VERSION')" >&2
  exit 1
fi

NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
NEW_VERSION="${VERSION_NAME}+${NEW_BUILD_NUMBER}"

# The Messages extension is a native target and does not inherit Flutter's
# generated build variables. Keep all three of its configurations aligned to
# the version being archived (the current pubspec value); the pubspec bump
# below prepares the next build, as Flutter has already generated xcconfig.
VERSION_NAME="$VERSION_NAME" BUILD_NUMBER="$BUILD_NUMBER" perl -0pi -e '
  s{CURRENT_PROJECT_VERSION = [^;]+;(.*?INFOPLIST_FILE = iMessageExtension/Info\.plist;.*?MARKETING_VERSION = )[^;]+;}
   {CURRENT_PROJECT_VERSION = $ENV{BUILD_NUMBER};$1$ENV{VERSION_NAME};}sg
' "$IOS_PROJECT"

sed -i '' -E "s/^version:.*/version: ${NEW_VERSION}/" "$PUBSPEC"

echo "bump_build_number: ${CURRENT_VERSION} -> ${NEW_VERSION}"
