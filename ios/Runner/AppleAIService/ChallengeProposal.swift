//
//  ChallengeProposal.swift
//  Runner
//
//  Phase 2 of the Dynamic AI Director: the on-device proposal schema and the
//  model availability rail. See docs/AI/Foundation Models Integration.md and
//  docs/AI/Development Plan.md.
//
//  Design notes
//  - The structs mirror lib/ai/generated_challenge.dart field for field so
//    generated output can later be handed to Dart's
//    `ChallengeProposal.fromJson` with no translation layer.
//  - `@Generable` and the whole FoundationModels surface are iOS 26.0+ only,
//    so the schema sits behind `#if canImport(FoundationModels)` plus
//    `@available(iOS 26.0, ...)`. On earlier OS it is compiled out entirely
//    and only the availability rail exists.
//  - `@Generable` cannot express Dictionary-typed fields, so `failLine` is
//    deliberately NOT part of the schema: the Swift provider fills it from
//    the mechanic's canonical fail lines when a proposal is built
//    (see the Decision Log entry "GeneratedChallenge vs ChallengeProposal").
//

import Foundation

// MARK: - Availability rail (always compiled; iOS 15 safe)

/// What the Dart `available` method reports back. Mirrors the wire contract
/// `{ state: "available" | "unavailable", reason?: string }`.
public struct AYSAppleAIStatus: Equatable, Sendable {
    public let isAvailable: Bool
    public let state: String
    public let reason: String

    public init(isAvailable: Bool, state: String, reason: String) {
        self.isAvailable = isAvailable
        self.state = state
        self.reason = reason
    }
}

public enum AYSAppleAIAvailabilityRail {
    /// Reads the on-device model availability. Fully synchronous: it only
    /// touches the availability enum, never generates or blocks.
    public static func snapshot() -> AYSAppleAIStatus {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                return AYSAppleAIStatus(
                    isAvailable: true, state: "available", reason: "")
            case .unavailable(let reason):
                let code: String
                switch reason {
                case .deviceNotEligible:
                    code = "deviceNotEligible"
                case .appleIntelligenceNotEnabled:
                    code = "appleIntelligenceNotEnabled"
                case .modelNotReady:
                    code = "modelNotReady"
                @unknown default:
                    code = "modelNotReady"
                }
                return AYSAppleAIStatus(
                    isAvailable: false, state: "unavailable", reason: code)
            }
        }
        #endif
        // Either this OS can't run the model (OS < 26) or the framework was
        // compiled out. The Dart side maps this to the same silent fallback.
        return AYSAppleAIStatus(
            isAvailable: false,
            state: "unavailable",
            reason: AYSAppleAIStatus.unsupportedOSReason)
    }
}

extension AYSAppleAIStatus {
    /// Why a non-incapable setup is still unavailable without the model.
    public static let unsupportedOSReason = "unsupportedOS"
}

// MARK: - Proposal schema (compiled out below iOS 26)

#if canImport(FoundationModels)
import FoundationModels

/// The model's portable, pre-validation proposal. Mirrors Dart's
/// `ChallengeProposal`; the validator on the Dart side is the authority.
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct AYSChallengeProposal: Sendable {
    public var id: String
    public var mechanic: AYSMechanicRef
    public var instruction: String
    public var elements: [AYSElement]
    public var correctAnswer: AYSCorrectAnswer
    public var difficulty: AYSDifficultySpec
    /// Drives the rng-backed layout for determinism (multiplayer). 0 = the
    /// provider decides (solo).
    public var seed: Int
    /// Always `ai` for model output; anything else fails the envelope check.
    public var source: String = "ai"
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct AYSMechanicRef: Sendable {
    /// Registry move name (check challenge_vocabulary.dart `kMechanicByMove`).
    public var move: String
    /// The imperative verb the instruction must contain, e.g. "TAP".
    public var action: String
    /// `native` | `shape` | `sound` etc. (informational).
    public var kind: String = ""
    /// Sense decoys (e.g. `[shape]`) for homophone-style tricks.
    public var senseDecoys: [String] = []
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct AYSElement: Sendable {
    public var id: String
    public var label: String
    /// Wire color/shape names; unknown ones are rejected by the validator as
    /// unrenderable.
    public var color: String
    public var shape: String
    /// Size multiplier (1.0 = normal), clamped by the validator.
    public var scale: Double
    /// Rotation in radians, magnitude ≤ 0.6 required.
    public var rotation: Double
    /// Wobble offsets (fraction of target size), each within ±0.6 required.
    public var dx: Double
    public var dy: Double
    public var opacity: Double
    public var hidden: Bool
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct AYSCorrectAnswer: Sendable {
    /// Must resolve to a proposal element id.
    public var elementId: String
    /// Meaningful for `swap` tricks: the correct element must *start* correct
    /// and swap away — a constant lie is rejected by the validator.
    public var startsCorrect: Bool
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct AYSDifficultySpec: Sendable {
    /// The round this proposal was written for (informational; the validator
    /// gates by the serving context's level).
    public var level: Int
    /// The round length the model proposes (validator enforces floors and the
    /// 8000 ms cap).
    public var timeLimitMs: Int
    /// Wire trick name; null-parseable values are rejected as unrenderable.
    public var trickType: String = "none"
}

#endif