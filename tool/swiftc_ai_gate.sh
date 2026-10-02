#!/bin/sh
#
# swiftc_ai_gate.sh — typecheck gate for the Apple Intelligence bridge.
#
# The AI Swift code (ios/Runner/AppleAIService/) must always compile against
# the real FoundationModels SDK in the installed Xcode, targeting the app's
# minimum iOS (15.0). This gate runs that check headlessly:
#
#   - `swiftc -typecheck` the two AI service files together with the iPhoneOS
#     SDK (this also exercises the `#if canImport(FoundationModels)` paths).
#   - passes `-F` so `import Flutter` resolves from the local engine cache.
#
# It exits 0 (skip) when the toolchain or engine module isn't available so the
# gate is safe on machines without the iOS SDK or before `flutter precache`.
# See docs/AI/Testing and Evaluation.md.
#
# Usage: tool/swiftc_ai_gate.sh  (from the repo root)

set -eu

cd "$(dirname "$0")/.."

SDK="$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || true)"
if [ -z "$SDK" ]; then
    echo "swiftc_ai_gate: skip (no iPhoneOS SDK)"
    exit 0
fi

FLUTTER_BIN="$(command -v flutter || true)"
if [ -z "$FLUTTER_BIN" ]; then
    echo "swiftc_ai_gate: skip (flutter not on PATH)"
    exit 0
fi
FLUTTER_ROOT="$(dirname "$(dirname "$(realpath "$FLUTTER_BIN")")")"
ENGINE="$FLUTTER_ROOT/bin/cache/artifacts/engine/ios/Flutter.xcframework"
FLUTTER_FRAMEWORK="$ENGINE/ios-arm64/Flutter.framework"

if [ ! -f "$FLUTTER_FRAMEWORK/Modules/module.modulemap" ]; then
    echo "swiftc_ai_gate: skip (Flutter iOS module not cached; run flutter precache --ios)"
    exit 0
fi

SRCS="ios/Runner/AppleAIService/ChallengeProposal.swift
ios/Runner/AppleAIService/CommentaryProfile.swift
ios/Runner/AppleAIService/GenerationTools.swift
ios/Runner/AppleAIService/ChallengeGenerationProfile.swift
ios/Runner/AppleAIService/AppleAIController.swift"

echo "swiftc_ai_gate: typechecking AI bridge (iPhoneOS $SDK)"
# shellcheck disable=SC2086
xcrun --sdk iphoneos swiftc -typecheck \
    -target arm64-apple-ios15.0 \
    -sdk "$SDK" \
    -F "$(dirname "$FLUTTER_FRAMEWORK")" \
    $SRCS
echo "swiftc_ai_gate: ok"