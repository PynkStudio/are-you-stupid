//
//  ChallengeGenerationProfile.swift
//  Runner
//
//  Real on-device challenge generation (Phase 6 of the AI Director plan —
//  docs/AI/AI Challenge Generation.md, docs/AI/Dynamic Profiles and Tool
//  Calling.md's `ChallengeGenerationProfile`). `AppleAIController.requestChallenge`
//  forwards here.
//
//  Same always-compiled-outer/`@available`-gated-inner split as
//  `AYSCommentaryService` (CommentaryProfile.swift) and
//  `AYSAppleAIAvailabilityRail` (ChallengeProposal.swift) — the enum and its
//  public entry point compile on every OS version; only the body that
//  actually touches `LanguageModelSession` sits behind
//  `#if canImport(FoundationModels)` + `@available(iOS 26.0, *)`.
//
//  `@Generable` gives no `Encodable` conformance (confirmed by probe-compiling
//  against the real SDK — `JSONEncoder().encode()` on an `AYSChallengeProposal`
//  fails to typecheck), so the wire dict is built by hand,
//  field-for-field, matching `lib/ai/generated_challenge.dart`'s
//  `ChallengeProposal.fromJson` exactly. `failLine` is filled here from
//  `kCanonicalFailLines` — the dictionary `@Generable` can't express
//  (documented in ChallengeProposal.swift's header) — keyed by `mechanic.move`,
//  English-only, matching the v1 English-only generation path.
//

import Foundation

/// One English fail line per mechanic — the piece `@Generable` can't
/// produce itself (no dictionary fields; see ChallengeProposal.swift).
/// Single sentence, ASCII, on the game's established deadpan voice
/// ([[AI Challenge Generation]] → "failLine is per-locale, one sentence,
/// and always present").
let kCanonicalFailLines: [String: String] = [
    "tap_true_color": "THE COLOR WAS THE ANSWER.",
    "tap_missing_color": "THAT COLOR WAS RIGHT THERE.",
    "tap_second_order": "THE ORDER CHANGED WITHOUT YOU.",
    "dont_tap_odd": "THAT WAS THE ONE TO AVOID.",
    "tap_every_but": "ONE WAS OFF LIMITS.",
    "obey_once_then_flip": "THE RULE FLIPPED BEFORE YOU DID.",
    "sequence_grow_remember": "THE SEQUENCE OUTGREW YOUR MEMORY.",
    "hold_true_color": "YOU LET GO TOO SOON.",
    "spam_until_stop": "NOT ENOUGH TAPS IN TIME.",
    "_default": "NOT QUITE.",
]

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AYSChallengeGenerationService {
    /// Entry point `AppleAIController` calls. Always safe to call from any
    /// OS version — internally branches on availability and never throws.
    static func requestChallenge(locale: String, payload: [String: Any]) async -> [String: Any] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return await _requestChallenge(locale: locale, payload: payload)
        }
        #endif
        return AYSAppleAIResponse.error(code: "unavailable", retryable: false)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private static func _requestChallenge(locale: String, payload: [String: Any]) async -> [String: Any] {
        guard AYSAppleAIAvailabilityRail.snapshot().isAvailable else {
            return AYSAppleAIResponse.error(code: "unavailable", retryable: false)
        }

        let profileDict = payload["playerProfile"] as? [String: Any] ?? [:]
        let profileSnapshot = AYSPlayerProfileSnapshot(
            mostCommonMistakeCategory: profileDict["mostCommonMistakeCategory"] as? String ?? "",
            successRateByMechanic: profileDict["successRateByMechanic"] as? [String] ?? [],
            averageReactionTimeMs: profileDict["averageReactionTimeMs"] as? Int ?? 0,
            fastestStreak: profileDict["fastestStreak"] as? Int ?? 0
        )
        let recentChallenges: [AYSRecentChallenge] = (payload["recentChallenges"] as? [[String: Any]] ?? []).map {
            AYSRecentChallenge(
                challengeId: $0["challengeId"] as? String ?? "",
                mechanic: $0["mechanic"] as? String ?? ""
            )
        }
        let availableMechanics = payload["availableMechanics"] as? [String] ?? []
        let level = payload["level"] as? Int ?? 1

        let session = LanguageModelSession(
            model: SystemLanguageModel.default,
            tools: [
                GetPlayerProfileTool(snapshot: profileSnapshot),
                GetRecentChallengesTool(recent: recentChallenges),
                GetAvailableMechanicsTool(mechanics: availableMechanics),
            ],
            instructions: instructions
        )
        // 0.9: high-temperature invention, matching every other
        // commentary/challenge call ([[Dynamic Profiles and Tool Calling]]).
        let options = GenerationOptions(temperature: 0.9, maximumResponseTokens: 512)
        do {
            let response = try await session.respond(
                to: prompt(level: level),
                generating: AYSChallengeProposal.self,
                options: options
            )
            return ["ok": true, "proposal": wireDict(for: response.content)]
        } catch let error as LanguageModelSession.GenerationError {
            return AYSAppleAIResponse.error(
                code: CommentaryErrorMapping.code(for: error),
                retryable: CommentaryErrorMapping.isRetryable(error)
            )
        } catch {
            return AYSAppleAIResponse.error(code: "unknown", retryable: false)
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private static let instructions = """
        You invent one short challenge for a hyper-casual reflex game called \
        ARE YOU STUPID?. Pick a mechanic from getAvailableMechanics, look at \
        getPlayerProfile and getRecentChallenges to vary things up, then \
        propose an instruction, the on-screen elements, and which one is \
        correct. The instruction must be under 8 words and ALL CAPS. Never \
        mention that you are an AI or a model.
        """

    @available(iOS 26.0, macOS 26.0, *)
    private static func prompt(level: Int) -> String {
        "The player is at level \(level). Propose one challenge."
    }

    /// Hand-built wire dict — see the file header on why this can't just be
    /// `JSONEncoder().encode(proposal)`.
    @available(iOS 26.0, macOS 26.0, *)
    private static func wireDict(for proposal: AYSChallengeProposal) -> [String: Any] {
        [
            "id": proposal.id,
            "mechanic": [
                "move": proposal.mechanic.move,
                "action": proposal.mechanic.action,
                "kind": proposal.mechanic.kind,
                "sense_decoys": proposal.mechanic.senseDecoys,
            ],
            "instruction": proposal.instruction,
            "elements": proposal.elements.map { element in
                [
                    "id": element.id,
                    "label": element.label,
                    "color": element.color,
                    "shape": element.shape,
                    "scale": element.scale,
                    "rotation": element.rotation,
                    "dx": element.dx,
                    "dy": element.dy,
                    "opacity": element.opacity,
                    "hidden": element.hidden,
                ] as [String: Any]
            },
            "correctAnswer": [
                "elementId": proposal.correctAnswer.elementId,
                "startsCorrect": proposal.correctAnswer.startsCorrect,
            ],
            "difficulty": [
                "level": proposal.difficulty.level,
                "timeLimitMs": proposal.difficulty.timeLimitMs,
                "trickType": proposal.difficulty.trickType,
            ],
            "failLine": ["en": kCanonicalFailLines[proposal.mechanic.move] ?? kCanonicalFailLines["_default"]!],
            "seed": proposal.seed,
            "source": proposal.source,
        ]
    }
    #endif
}

/// Shared with `AYSCommentaryService` (CommentaryProfile.swift) — the same
/// `LanguageModelSession.GenerationError` → wire error code mapping,
/// factored out once both callers needed it. Content-level failures
/// (`guardrailViolation`/`refusal`) are never retried as-is
/// ([[Quality Neutrality and Guardrails]] guardrail #7); everything else is
/// transient/environmental and safe to retry on a later unit.
#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
enum CommentaryErrorMapping {
    static func code(for error: LanguageModelSession.GenerationError) -> String {
        switch error {
        case .guardrailViolation: return "guardrailViolation"
        case .refusal: return "refusal"
        case .rateLimited: return "rateLimited"
        case .concurrentRequests: return "concurrentRequests"
        case .exceededContextWindowSize: return "exceededContextWindowSize"
        case .assetsUnavailable: return "assetsUnavailable"
        case .unsupportedLanguageOrLocale: return "unsupportedLanguageOrLocale"
        case .decodingFailure: return "decodingFailure"
        case .unsupportedGuide: return "decodingFailure"
        @unknown default: return "unknown"
        }
    }

    static func isRetryable(_ error: LanguageModelSession.GenerationError) -> Bool {
        switch error {
        case .guardrailViolation, .refusal:
            return false
        default:
            return true
        }
    }
}
#endif
