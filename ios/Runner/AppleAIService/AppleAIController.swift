//
//  AppleAIController.swift
//  Runner
//
//  Registers the `ays/apple_intelligence` MethodChannel (Phase 2 of the
//  Dynamic AI Director). See docs/AI/Foundation Models Integration.md for the
//  wire contract. The Dart side of the contract lives in
//  lib/ai/apple_ai_service.dart; `available` is the authority for what the
//  model can do right now.
//
//  Phase 6 behaviour:
//  - `available`         — real, reads the on-device model (iOS 26+).
//  - `requestCommentary` — real (CommentaryProfile.swift): a plain-text
//    LanguageModelSession call, re-validated on the Dart side
//    (lib/ai/commentary.dart's isCommentaryLineValid) before it ever reaches
//    a player.
//  - `requestChallenge`  — real (ChallengeGenerationProfile.swift): a
//    constrained `AYSChallengeProposal` generation with `@Guide`d bounds
//    (ChallengeProposal.swift) and three snapshot-backed tools
//    (GenerationTools.swift). `ChallengeValidator` on the Dart side remains
//    the actual authority regardless.
//  - `requestFinalRound`/`requestMultiplayerHost` — still stubbed with a
//    `notImplemented` error (no caller needs them yet — solo's "final round"
//    concept and the multiplayer Director are both later work). The Dart
//    side treats any `error` block exactly like a fallback: silent, never
//    blocks the game.
//  - `cancelUnit`        — returns true (no in-flight work yet).
//  - `feedback`          — accepted but dropped until the loopback phase.
//

import Flutter
import Foundation

public final class AppleAIController: NSObject {
    public static let channelName = "ays/apple_intelligence"

    private let channel: FlutterMethodChannel

    public init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: Self.channelName,
            binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "available":
            let status = AYSAppleAIAvailabilityRail.snapshot()
            let payload: [String: Any] = status.isAvailable
                ? ["state": "available"]
                : ["state": "unavailable", "reason": status.reason]
            DispatchQueue.main.async { result(payload) }
        case "requestCommentary":
            guard
                let args = call.arguments as? [String: Any],
                let kind = args["kind"] as? String
            else {
                result(AYSAppleAIResponse.error(code: "decodingFailure", retryable: false))
                return
            }
            let locale = args["locale"] as? String ?? "en"
            let context = args["context"] as? [String: Any] ?? [:]
            Task {
                let payload = await AYSCommentaryService.requestCommentary(
                    kind: kind, locale: locale, context: context)
                await MainActor.run { result(payload) }
            }
        case "requestChallenge":
            guard let args = call.arguments as? [String: Any] else {
                result(AYSAppleAIResponse.error(code: "decodingFailure", retryable: false))
                return
            }
            let locale = args["locale"] as? String ?? "en"
            let payload = args["profile"] as? [String: Any] ?? [:]
            Task {
                let response = await AYSChallengeGenerationService.requestChallenge(
                    locale: locale, payload: payload)
                await MainActor.run { result(response) }
            }
        case "requestFinalRound",
             "requestMultiplayerHost":
            result(AYSAppleAIResponse.error(code: "notImplemented", retryable: false))
        case "cancelUnit":
            result(true)
        case "feedback":
            result(false)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

/// Response-building helpers matching the wire contract in
/// lib/ai/apple_ai_service.dart (error results, not throws).
enum AYSAppleAIResponse {
    static func error(code: String, retryable: Bool) -> [String: Any] {
        [
            "ok": false,
            "error": [
                "code": code,
                "retryable": retryable,
            ],
        ]
    }
}