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
//  (documented in ChallengeProposal.swift's header) — keyed by locale then
//  `mechanic.move`. Hand-written, not generated: the fail line is the
//  one-line explanation the design pillars require, so it stays predictable
//  even when the model's own text is off. Instruction and labels are written
//  by the model in the player's language (docs/AI/Localization and
//  Language.md).
//

import Foundation

/// One fail line per mechanic per game locale — the piece `@Generable`
/// can't produce itself (no dictionary fields; see ChallengeProposal.swift).
/// Single sentence, uppercase, on the game's established deadpan voice
/// ([[AI Challenge Generation]] → "failLine is per-locale, one sentence,
/// and always present"). English stays ASCII.
let kCanonicalFailLines: [String: [String: String]] = [
    "en": [
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
    ],
    "it": [
        "tap_true_color": "LA RISPOSTA ERA IL COLORE.",
        "tap_missing_color": "QUEL COLORE ERA LÌ DAVANTI.",
        "tap_second_order": "L'ORDINE È CAMBIATO SENZA DI TE.",
        "dont_tap_odd": "ERA PROPRIO QUELLO DA EVITARE.",
        "tap_every_but": "UNO ERA VIETATO.",
        "obey_once_then_flip": "LA REGOLA È CAMBIATA PRIMA DI TE.",
        "sequence_grow_remember": "LA SEQUENZA HA BATTUTO LA TUA MEMORIA.",
        "hold_true_color": "HAI MOLLATO TROPPO PRESTO.",
        "spam_until_stop": "TROPPO POCHI TOCCHI IN TEMPO.",
        "_default": "NON PROPRIO.",
    ],
    "fr": [
        "tap_true_color": "LA RÉPONSE, C'ÉTAIT LA COULEUR.",
        "tap_missing_color": "CETTE COULEUR ÉTAIT JUSTE LÀ.",
        "tap_second_order": "L'ORDRE A CHANGÉ SANS TOI.",
        "dont_tap_odd": "C'ÉTAIT CELUI À ÉVITER.",
        "tap_every_but": "UN ÉTAIT INTERDIT.",
        "obey_once_then_flip": "LA RÈGLE A CHANGÉ AVANT TOI.",
        "sequence_grow_remember": "LA SÉQUENCE A DÉPASSÉ TA MÉMOIRE.",
        "hold_true_color": "TU AS LÂCHÉ TROP TÔT.",
        "spam_until_stop": "PAS ASSEZ DE TAPS À TEMPS.",
        "_default": "PAS TOUT À FAIT.",
    ],
    "es": [
        "tap_true_color": "LA RESPUESTA ERA EL COLOR.",
        "tap_missing_color": "ESE COLOR ESTABA AHÍ MISMO.",
        "tap_second_order": "EL ORDEN CAMBIÓ SIN TI.",
        "dont_tap_odd": "ERA EL QUE HABÍA QUE EVITAR.",
        "tap_every_but": "UNO ESTABA PROHIBIDO.",
        "obey_once_then_flip": "LA REGLA CAMBIÓ ANTES QUE TÚ.",
        "sequence_grow_remember": "LA SECUENCIA SUPERÓ TU MEMORIA.",
        "hold_true_color": "SOLTASTE DEMASIADO PRONTO.",
        "spam_until_stop": "NO TOCASTE LO SUFICIENTE A TIEMPO.",
        "_default": "NO DEL TODO.",
    ],
    "pt": [
        "tap_true_color": "A RESPOSTA ERA A COR.",
        "tap_missing_color": "AQUELA COR ESTAVA BEM ALI.",
        "tap_second_order": "A ORDEM MUDOU SEM VOCÊ.",
        "dont_tap_odd": "ERA ESSE QUE DEVIA EVITAR.",
        "tap_every_but": "UM ERA PROIBIDO.",
        "obey_once_then_flip": "A REGRA MUDOU ANTES DE VOCÊ.",
        "sequence_grow_remember": "A SEQUÊNCIA SUPEROU SUA MEMÓRIA.",
        "hold_true_color": "VOCÊ SOLTOU CEDO DEMAIS.",
        "spam_until_stop": "TOQUES INSUFICIENTES A TEMPO.",
        "_default": "NÃO EXATAMENTE.",
    ],
    "de": [
        "tap_true_color": "DIE FARBE WAR DIE ANTWORT.",
        "tap_missing_color": "DIE FARBE WAR DIREKT DA.",
        "tap_second_order": "DIE REIHENFOLGE HAT SICH OHNE DICH GEÄNDERT.",
        "dont_tap_odd": "GENAU DEN SOLLTEST DU MEIDEN.",
        "tap_every_but": "EINER WAR TABU.",
        "obey_once_then_flip": "DIE REGEL WAR SCHNELLER ALS DU.",
        "sequence_grow_remember": "DIE FOLGE WAR LÄNGER ALS DEIN GEDÄCHTNIS.",
        "hold_true_color": "ZU FRÜH LOSGELASSEN.",
        "spam_until_stop": "ZU WENIGE TAPS IN DER ZEIT.",
        "_default": "NICHT GANZ.",
    ],
]

/// The fail line for [move] in [locale]; falls back to English, then the
/// locale's (or English) generic line.
func canonicalFailLine(locale: String, move: String) -> String {
    let table = kCanonicalFailLines[locale] ?? kCanonicalFailLines["en"]!
    return table[move] ?? table["_default"] ?? kCanonicalFailLines["en"]!["_default"]!
}

/// The output language named in the generation/commentary prompts.
func aysLanguageName(for locale: String) -> String {
    switch locale {
    case "it": return "Italian"
    case "fr": return "French"
    case "es": return "Spanish"
    case "pt": return "Portuguese"
    case "de": return "German"
    default: return "English"
    }
}

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
            instructions: instructions(locale: locale)
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
            return ["ok": true, "proposal": wireDict(for: response.content, locale: locale)]
        } catch let error as LanguageModelSession.GenerationError {
            return AYSAppleAIResponse.error(
                code: CommentaryErrorMapping.code(for: error),
                retryable: CommentaryErrorMapping.isRetryable(error)
            )
        } catch {
            return AYSAppleAIResponse.error(code: "unknown", retryable: false)
        }
    }

    /// The prompt stays English; only the on-screen text (instruction and
    /// element labels) is asked for in the player's language.
    @available(iOS 26.0, macOS 26.0, *)
    private static func instructions(locale: String) -> String {
        let language = aysLanguageName(for: locale)
        let length = locale == "en"
            ? "under 8 words"
            : "as short as possible, ideally under 8 words and never more than 10"
        return """
        You invent one short challenge for a hyper-casual reflex game called \
        ARE YOU STUPID?. Pick a mechanic from getAvailableMechanics, look at \
        getPlayerProfile and getRecentChallenges to vary things up, then \
        propose an instruction, the on-screen elements, and which one is \
        correct. Write the instruction and every element label in \
        \(language). The instruction must be \(length), ALL CAPS, and start \
        with a plain imperative verb (like the \(language) for TAP, HOLD or \
        DON'T TAP). Never mention that you are an AI or a model.
        """
    }

    @available(iOS 26.0, macOS 26.0, *)
    private static func prompt(level: Int) -> String {
        "The player is at level \(level). Propose one challenge."
    }

    /// Hand-built wire dict — see the file header on why this can't just be
    /// `JSONEncoder().encode(proposal)`.
    @available(iOS 26.0, macOS 26.0, *)
    private static func wireDict(for proposal: AYSChallengeProposal, locale: String) -> [String: Any] {
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
            "failLine": [locale: canonicalFailLine(locale: locale, move: proposal.mechanic.move)],
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
