//
//  GenerationTools.swift
//  Runner
//
//  The `Tool` conformances `ChallengeGenerationProfile` hands to its
//  `LanguageModelSession` (Phase 6 — [[Dynamic Profiles and Tool Calling]]).
//
//  **Scope decision, logged in docs/Meta/Decision Log.md:** the design doc
//  describes tools that "call back into Dart via a tool bridge" for live
//  game state. A real bidirectional bridge (a Swift `Tool.call()` making a
//  reverse `FlutterMethodChannel` call into the running Dart engine mid-
//  generation) would be genuinely novel, hard to verify without a real
//  device, and — for `ChallengeGenerationProfile` specifically — unnecessary:
//  `requestChallenge`'s existing `profile` argument already carries
//  everything these three tools would otherwise fetch live. So each tool
//  here is backed by a **snapshot Dart already computed and sent up front**,
//  not a live callback. This still exercises the real `Tool` protocol and
//  constrained tool-calling behavior (the model decides whether/when to
//  call each tool during generation and gets a real typed response) —
//  only the data source is pre-fetched rather than a live round trip.
//  `GetCurrentScoresTool` (multiplayer-only) and `ValidateChallengeTool`
//  (would need a partial Swift port of the Dart validator, which this
//  project has deliberately avoided duplicating since the judging-authority
//  redesign earlier in the multiplayer work) are not implemented here.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct AYSNoArguments: Sendable {}

// MARK: - GetPlayerProfileTool

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct AYSPlayerProfileSnapshot: Sendable {
    /// Enum name or empty when the player has no classified mistakes yet.
    var mostCommonMistakeCategory: String
    /// `"mechanicId:rate"` pairs, rate already rounded to the nearest 10%
    /// on the Dart side ([[Privacy and Offline]] — nothing more precise
    /// than that ever leaves the device).
    var successRateByMechanic: [String]
    var averageReactionTimeMs: Int
    var fastestStreak: Int
}

@available(iOS 26.0, macOS 26.0, *)
struct GetPlayerProfileTool: Tool {
    let name = "getPlayerProfile"
    let description = "Returns a compact, anonymized summary of this player's recent performance."
    let snapshot: AYSPlayerProfileSnapshot

    func call(arguments: AYSNoArguments) async throws -> AYSPlayerProfileSnapshot {
        snapshot
    }
}

// MARK: - GetRecentChallengesTool

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct AYSRecentChallenge: Sendable {
    var challengeId: String
    var mechanic: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct AYSRecentChallenges: Sendable {
    /// Last 4 served, ids + mechanic only — never raw content.
    var recent: [AYSRecentChallenge]
}

@available(iOS 26.0, macOS 26.0, *)
struct GetRecentChallengesTool: Tool {
    let name = "getRecentChallenges"
    let description = "Returns the last few challenges already served, so a new one avoids repeating them."
    let recent: [AYSRecentChallenge]

    func call(arguments: AYSNoArguments) async throws -> AYSRecentChallenges {
        AYSRecentChallenges(recent: recent)
    }
}

// MARK: - GetAvailableMechanicsTool

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct AYSAvailableMechanics: Sendable {
    /// Mechanic ids whose `minLevel` is at or below the serving context's
    /// level (and trick-enabled variants only when `allowTricks`) — mirrors
    /// the registry, computed on the Dart side.
    var mechanics: [String]
}

@available(iOS 26.0, macOS 26.0, *)
struct GetAvailableMechanicsTool: Tool {
    let name = "getAvailableMechanics"
    let description = "Returns which mechanic ids are eligible to propose at this level."
    let mechanics: [String]

    func call(arguments: AYSNoArguments) async throws -> AYSAvailableMechanics {
        AYSAvailableMechanics(mechanics: mechanics)
    }
}

#endif
