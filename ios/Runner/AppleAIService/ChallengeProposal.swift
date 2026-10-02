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
/// `ChallengeProposal`; the validator on the Dart side remains the
/// authority regardless of these `@Guide`s (Phase 6 — [[Dynamic Profiles
/// and Tool Calling]]). Guides *steer* generation toward the closed
/// vocabulary/bounds and reject a candidate outright when it violates a
/// hard constraint (`.anyOf`, `.pattern`, `.range`, `.count`) — but several
/// real rules genuinely can't be expressed here at all (the per-mechanic
/// time floor, the mechanic/kind/trick cross-consistency contract, decoy
/// honesty, freshness against recently-served rounds, tone) or only
/// partially (the instruction pattern approximates "≤ 8 words, uppercase"
/// with a regex, it doesn't parse word count precisely). `ChallengeValidator`
/// re-checks everything from scratch regardless of what a guide already
/// constrained — these are a quality/efficiency improvement (fewer
/// regenerations), never a substitute for it.
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct AYSChallengeProposal: Sendable {
    @Guide(description: "unique id", .pattern(try! Regex("ai\\.[a-z0-9]{5}")))
    public var id: String
    public var mechanic: AYSMechanicRef
    @Guide(description: "the on-screen instruction: at most 8 words, uppercase only",
           .pattern(try! Regex("[A-Z0-9'\\-]+( [A-Z0-9'\\-]+){0,7}")))
    public var instruction: String
    @Guide(description: "the tappable elements on screen", .count(2...6))
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
    /// Registry move name — closed vocabulary,
    /// `lib/ai/challenge_vocabulary.dart`'s `kMechanicByMove`.
    @Guide(.anyOf([
        "tap_true_color", "tap_missing_color", "tap_second_order", "dont_tap_odd",
        "tap_every_but", "obey_once_then_flip", "sequence_grow_remember",
        "hold_true_color", "spam_until_stop",
    ]))
    public var move: String
    /// The imperative verb the instruction must contain, e.g. "TAP".
    @Guide(.anyOf([
        "tap", "tap_many", "hold", "donot_tap", "tap_sequence", "tap_until_stop",
        "color_pick",
    ]))
    public var action: String
    /// The kind of play this mechanic produces; must match the move's own
    /// registered kind.
    @Guide(.anyOf([
        "mixed", "perception", "sequence", "trick", "counting", "rule_flip",
        "memory", "hold", "timing",
    ]))
    public var kind: String = ""
    /// Sense dimensions this mechanic plays on (e.g. `[color, label]`) — every
    /// declared dimension must be a real difference between the correct
    /// element and some decoy.
    @Guide(.count(0...3), .element(.anyOf([
        "color", "label", "shape", "size", "rotation", "opacity", "position",
    ])))
    public var senseDecoys: [String] = []
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct AYSElement: Sendable {
    public var id: String
    public var label: String
    /// Wire color name — closed vocabulary, same set as the engine's
    /// `GameColor`.
    @Guide(.anyOf([
        "red", "blue", "green", "yellow", "purple", "orange", "pink", "white",
        "slate",
    ]))
    public var color: String
    /// Wire shape name — closed vocabulary, the engine's `TargetShape`.
    @Guide(.anyOf(["rect", "circle", "triangle", "diamond"]))
    public var shape: String
    /// Size multiplier (1.0 = normal); the validator's real bounds.
    @Guide(.range(0.45...2.0))
    public var scale: Double
    /// Rotation in radians, magnitude ≤ 0.6 required.
    @Guide(.range(-0.6...0.6))
    public var rotation: Double
    /// Wobble offsets (fraction of target size), each within ±0.6 required.
    @Guide(.range(-0.6...0.6))
    public var dx: Double
    @Guide(.range(-0.6...0.6))
    public var dy: Double
    @Guide(.range(0.35...1.0))
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
    @Guide(.range(1...99))
    public var level: Int
    /// The round length the model proposes. The validator's real floor
    /// varies by mechanic (see `ChallengeMechanic.floorMs`) so this guide can
    /// only encode the shared, mechanic-independent bounds: never above the
    /// hard 8000ms cap, never a degenerate near-zero value.
    @Guide(.range(200...8000))
    public var timeLimitMs: Int
    /// Wire trick name — closed vocabulary; `none` is always safe, the rest
    /// require `allowTricks` (validator-enforced, not expressible here).
    @Guide(.anyOf([
        "none", "swap", "fake_button", "sequence", "rule_flip", "color_shifts",
        "requires_anomaly",
    ]))
    public var trickType: String = "none"
}

#endif