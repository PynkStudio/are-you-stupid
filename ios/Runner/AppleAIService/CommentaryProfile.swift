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
//  the Dart side (charset, length, tone, one sentence).
//
//  Commentary is written in the player's language (en/it/fr/es/pt/de — all
//  supported by the on-device model); challenge generation stays English
//  (docs/AI/Localization and Language.md). The prompt carries the moment's
//  facts from the Dart `context` map (e.g. the Game Over verdict's level,
//  best and the instruction that ended the run). Every proposal-style
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
            instructions: instructions(locale: locale, context: context)
        )
        // 0.9: high-temperature invention, matching every other
        // commentary/challenge call ([[Dynamic Profiles and Tool Calling]]).
        // 40 tokens is generous for a sub-12-word line without leaving room
        // for the model to ramble past one sentence.
        let options = GenerationOptions(temperature: 0.9, maximumResponseTokens: 40)
        do {
            let response = try await session.respond(
                to: prompt(for: kind, context: context), options: options)
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

    /// Compiled-in system prompt per [[Dynamic Profiles and Tool Calling]].
    /// The prompt itself stays English; only the requested *output*
    /// language follows [locale].
    @available(iOS 26.0, macOS 26.0, *)
    private static func instructions(locale: String, context: [String: Any]) -> String {
        let language = aysLanguageName(for: locale)
        let charset = locale == "en"
            ? "plain ASCII only"
            : "plain text in \(language) (accented letters are fine)"
        let tone = (context["spicy"] as? Bool) == false
            ? "Keep it gentle: light teasing only, no insults."
            : "The tone is playful teasing, never actual cruelty."
        return """
        You write exactly one short, deadpan line of commentary for a \
        hyper-casual reflex game called ARE YOU STUPID?, where the player gets \
        a stupidly simple instruction and fails on something stupid. \
        \(tone) Never a slur, never a reference to a real person. \
        Write the line in \(language). Reply with exactly one sentence, \
        \(charset), no emoji, no markdown, no quotation marks, and never \
        mention that you are an AI, a model, or that you were generated.
        """
    }

    @available(iOS 26.0, macOS 26.0, *)
    private static func prompt(for kind: String, context: [String: Any]) -> String {
        var lines = ["The moment to comment on is: \(kind)."]
        if let guidance = kindGuidance[kind] {
            lines.append(guidance)
        }
        let maxWords = (kind == "correct" || kind == "streak") ? 6 : 12
        lines.append("Use at most \(maxWords) words.")
        let facts = context
            .filter { $0.key != "recentLines" && $0.key != "spicy" }
            .sorted { $0.key < $1.key }
            .map { "- \($0.key): \($0.value)" }
        if !facts.isEmpty {
            lines.append("Facts about this moment:")
            lines.append(contentsOf: facts)
        }
        if let recent = context["recentLines"] as? [String], !recent.isEmpty {
            lines.append("Do not repeat any of these lines:")
            lines.append(contentsOf: recent.map { "- \($0)" })
        }
        return lines.joined(separator: "\n")
    }

    private static let kindGuidance: [String: String] = [
        "wrong": "The player just failed a stupidly simple instruction. Tease the mistake.",
        "gameOver": "The player's run just ended. Give a verdict on the whole run, "
            + "using the facts (the level they reached, their best, the instruction "
            + "that beat them). A new personal best deserves backhanded praise.",
        "correct": "The player got it right. Dry, grudging praise.",
        "streak": "The player is on a fast streak. Escalate the grudging praise.",
    ]

    #endif
}
