//
//  CommentaryProfile.swift
//  Runner
//
//  Real on-device commentary generation (Phase 4 of the AI Director plan —
//  docs/AI/AI Commentary.md, docs/AI/Dynamic Profiles and Tool Calling.md's
//  `CommentaryProfile`). `AppleAIController.requestCommentary` forwards here.
//
//  Mirrors `AYSAppleAIAvailabilityRail` (ChallengeProposal.swift)'s split:
//  `requestCommentary` always compiles and is always callable from any iOS
//  version; the real `LanguageModelSession` call lives behind
//  `#if canImport(FoundationModels)` + `@available(iOS 26.0, *)`, and every
//  path below that gate returns the same `unavailable` shape the bridge
//  already treats as a silent, scripted-fallback trigger on the Dart side —
//  see `lib/ai/commentary.dart`'s static-bank-first ladder.
//
//  The model is asked for plain text, not a `@Generable` schema — a single
//  short line has nothing worth constraining beyond what
//  `lib/ai/commentary.dart`'s `isCommentaryLineValid` already re-checks on
//  the Dart side (ASCII, length, tone, one sentence). Every proposal-style
//  `@Generable` struct stays in ChallengeProposal.swift; this file never
//  invents a second schema for the same concept.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AYSCommentaryService {
    /// Entry point `AppleAIController` calls. Always safe to call from any
    /// OS version — internally branches on availability and never throws.
    static func requestCommentary(
        kind: String,
        locale: String,
        context: [String: Any]
    ) async -> [String: Any] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return await _requestCommentary(kind: kind, locale: locale, context: context)
        }
        #endif
        return AYSAppleAIResponse.error(code: "unavailable", retryable: false)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private static func _requestCommentary(
        kind: String,
        locale: String,
        context: [String: Any]
    ) async -> [String: Any] {
        guard AYSAppleAIAvailabilityRail.snapshot().isAvailable else {
            return AYSAppleAIResponse.error(code: "unavailable", retryable: false)
        }
        let session = LanguageModelSession(
            model: SystemLanguageModel.default,
            tools: [],
            instructions: instructions(for: kind)
        )
        // 0.9: high-temperature invention, matching every other
        // commentary/challenge call ([[Dynamic Profiles and Tool Calling]]).
        // 40 tokens is generous for a sub-12-word line without leaving room
        // for the model to ramble past one sentence.
        let options = GenerationOptions(temperature: 0.9, maximumResponseTokens: 40)
        do {
            let response = try await session.respond(to: prompt(for: kind, context: context), options: options)
            return ["ok": true, "text": response.content]
        } catch let error as LanguageModelSession.GenerationError {
            return AYSAppleAIResponse.error(
                code: CommentaryErrorMapping.code(for: error),
                retryable: CommentaryErrorMapping.isRetryable(error)
            )
        } catch {
            return AYSAppleAIResponse.error(code: "unknown", retryable: false)
        }
    }

    /// English-only, compiled-in system prompt per
    /// [[Dynamic Profiles and Tool Calling]] — v1 model output stays
    /// English regardless of [locale] ([[Localization and Language]]); the
    /// bridge caller (`lib/ai/commentary.dart`) never calls this for a
    /// non-English locale in the first place.
    @available(iOS 26.0, macOS 26.0, *)
    private static func instructions(for kind: String) -> String {
        """
        You write exactly one short, deadpan line of commentary for a \
        hyper-casual reflex game called ARE YOU STUPID?. The tone is playful \
        teasing, never actual cruelty, never a slur, never a reference to a \
        real person. Reply with exactly one sentence, plain ASCII only, no \
        emoji, no markdown, and never mention that you are an AI, a model, \
        or that you were generated.
        """
    }

    @available(iOS 26.0, macOS 26.0, *)
    private static func prompt(for kind: String, context: [String: Any]) -> String {
        "The moment to comment on is: \(kind)."
    }
    #endif
}
