---
tags: [ai, architecture, ios, swift]
updated: 2026-09-07
---

# Foundation Models Integration

The native side. **No other layer talks to `FoundationModels`** — not a widget,
not the engine, not `lib/core/`.

## Platform reality (verified against the SDK)

- `FoundationModels.framework` ships in the **iPhoneOS 26.5 SDK**, module
  version 1.5.2. Phase 2 verified (via `swiftc -typecheck` against the real
  SDK) that this Xcode generation ships the **session-based API** —
  `LanguageModelSession` / `SystemLanguageModel` / `GenerationOptions` — not
  the WWDC25 preview `GenerativeModel`/`Text` forms. The API is annotated
  `iOS 26.0+ / macOS 26.0+ / visionOS 26.0+`, **`tvOS` and `watchOS`
  unavailable** — this is why the Apple TV can never be an AI compute node
  ([[Multiplayer AI Director]]).
- The app's deployment target is **iOS 15.0**. Every native use sits behind
  `#if canImport(FoundationModels)` (compile) **and**
  `if #available(iOS 26.0, *)` (runtime). On any earlier OS the bridge reports
  `unavailable` immediately and the Dart side behaves exactly as if the model
  were absent.
- Real model inference **cannot be exercised in this repo's normal dev
  environment** (no Apple Intelligence on the simulators used here). The
  Swift side is type-checked; behaviour is covered by mocks on the Dart side
  ([[Testing and Evaluation]]).

## Availability ladder

The Dart side needs to know *why* the feature is off to answer
[[Feature Flags]] → AI Experience Modes and the Settings copy honestly:

| State | Source | Meaning |
|---|---|---|
| `supported` | OS + capability | device could run the model |
| `available` | `SystemLanguageModel.default.availability == .available` | model ready right now |
| `downloading` | `availability != .available && != .unavailable(...)` | **n/a in this API** — see below |
| `unavailable(deviceNotEligible)` | availability enum | hardware/OS can't run it |
| `unavailable(appleIntelligenceNotEnabled)` | availability enum | user hasn't turned on Apple Intelligence (or locale not yet downloaded) |
| `unavailable(modelNotReady)` | availability enum | model not downloaded yet |
| `unavailable` (bridge level) | OS < 26, or `canImport` failed | compiled out entirely |

`SystemLanguageModel.Availability` is exactly two cases:
`.available` and `.unavailable(UnavailableReason)` with
`UnavailableReason ∈ { .deviceNotEligible, .appleIntelligenceNotEnabled,
.modelNotReady }`. There is **no explicit "downloading" state in this
release** — the availability getter resolves to one of the three reasons; the
bridge maps any non-`.available` to Dart's `unavailableByOS` bucket with the
reason string attached so UI copy can differ.

`SystemLanguageModel.default` is used as-is. Its `contextSize` is **4096**
tokens; `supportedLanguages` / `supportsLocale(_:)` gate AI localization
([[Localization and Language]]).

## The generated-answer model

Per the spec's "structure over free text" rule, **every** model call is a
**constrained generation** against a `GenerationSchema` — never an open-ended
prompt whose text is then parsed. The Swift plugin owns the schema
definitions; the Dart side sends semantic requests (an enum + a JSON payload),
never prose.

Key API used (from the Module 1.5.2 interface, verified in Phase 2):

```swift
// Model handle
SystemLanguageModel.default                       // availability, isAvailable
#available(iOS 26.0, *)  // guard, or the model headers are not even visible

// One-shot session
let session = LanguageModelSession(model: SystemLanguageModel.default,
                                   tools: [...],           // see [[Dynamic Profiles and Tool Calling]]
                                   instructions: "...")     // global system prompt

// Constrained generation → JSON, never free text
let response = try await session.respond(
    to: prompt,
    generating: ChallengeProposal.self,          // <T: Generable>
    includeSchemaInPrompt: true,
    options: GenerationOptions(
        temperature: 0.9,
        maximumResponseTokens: 512,
        sampling: ...                            // greedy or random — seed available for determinism
    )
)
// response.content: the decoded @Generable struct; also response.rawContent
// and response.transcriptEntries for logging.
```

`registrar.messenger()` on the Flutter side is a zero-argument **method** (the
imported ObjC module has no Swift overlay); the controller takes the returned
`FlutterBinaryMessenger` directly.

### `@Generable` structs vs hand-built `GenerationSchema`

Preferred: `@Generable` Swift structs (one per semantic request), because the
macro generates both the `GenerationSchema` and the typed decoding — and, for
`Tool` arguments, the `ConvertibleFromGeneratedContent` conformance. Every
`@Generable` field uses a `Guide`:

- strings → `.constant("...")`, `.anyOf([...])` (closed vocabulary:
  challenges, mechanics, colors, reasons), or `.pattern(regex)` (ids);
- ints → `.range(min...max)` (level, thresholds, time limits, counts);
- arrays → `.count(min...max)` / `.element(...)`.

Phase 2 verified macro constraints ([[AI Challenge Generation]] →
`ChallengeProposal`):

- each struct needs `@available(iOS 26.0, macOS 26.0, *)` directly above
  `@Generable`, or the macro is rejected;
- `[String: String]`-style **dictionary fields are not supported**
  (`'PartiallyGenerated' is not a member type of generic struct '…'`) — the
  per-locale `failLine` map is therefore *not* part of the schema; the Swift
  provider injects it from the mechanic's canonical fail lines at build time.

Hand-built `GenerationSchema` (`GenerationSchema.Property(name:type:guides:)`)
remains available for requests where a plain Swift struct doesn't fit; the
same guides apply. **A property with no guide is a bug** — the validator
relies on the schema nailing the vocabulary down ([[AI Challenge Validator]]).

### Generation options

- `GenerationOptions.temperature` — high (≳ 0.8) for challenge/commentary
  invention; low (≈ 0.2) for the final-round/multiplayer questions where the
  model must stick to *this* player's data.
- `GenerationOptions.maximumResponseTokens` — a hard cap per request so one
  runaway generation can't starve the CPU/battery budget
  ([[Performance and Resource Budgets]]).
- `SamplingMode.random(top:, seed:)` — the `seed` is used by the Dart layer to
  make multi-device rounds deterministic where the spec requires it
  ([[Multiplayer AI Director]]).

### Errors that drive fallback

`LanguageModelSession.GenerationError` cases map 1:1 to the
[[Feature Flags]] auto-disable reasons. The important ones for this product:

- `.guardrailViolation`, `.refusal` → treat as content-level failure: do **not**
  retry the same prompt, mark the unit failed, next prefetch continues
  ([[Quality Neutrality and Guardrails]]).
- `.rateLimited`, `.concurrentRequests`, `.exceededContextWindowSize`,
  `.assetsUnavailable`, `.unsupportedLanguageOrLocale`,
  `.decodingFailure` → transient/environmental: throttle, then resume the
  prefetch loop.
- `ToolCallError` → the tool itself failed; the single-tool request is aborted
  and the unit is skipped ([[Dynamic Profiles and Tool Calling]]).

## The MethodChannel contract (Dart ⇄ Swift)

A single channel **`ays/apple_intelligence`** (constant
`kAppleIntelligenceChannel` in `lib/ai/apple_ai_service.dart`) is registered
in `AppDelegate.didInitializeImplicitFlutterEngine(:)` (the runner uses
`FlutterImplicitEngineDelegate`; the controller is retained for app lifetime),
in `ios/Runner/AppleAIService/AppleAIController.swift`. Every call is
**request → JSON proposal**; the channel never streams the model to Dart, and
Dart never sees the session.

| Method | Request → payload | Response |
|---|---|---|
| `available` | none | `{ state: "available"\|"unavailable", reason?: string }` |
| `requestChallenge` | `{ unitId, locale, profile }` | `{ ok: bool, proposal?: challengeJson, error?: { code, retryable } }` |
| `requestCommentary` | `{ unitId, locale, kind, context }` | `{ ok: bool, text?: string, error?: ... }` |
| `requestFinalRound` / `requestMultiplayerHost` | profiles + per-spec context | same `ok/proposal` shape |
| `cancelUnit` | `{ unitId }` | `true` (best-effort; generation is a single await that completes or is discarded) |
| `feedback` | `{ sentiment, issue, excerpt }` | `true` (best-effort; nothing depends on it) |

**Phase 2 status:** `available` is fully implemented (reads
`SystemLanguageModel.default.availability` through
`AYSAppleAIAvailabilityRail`). The four generation methods return the error
envelope `{ ok: false, error: { code: "notImplemented", retryable: false } }`
until Phases 4–5; `cancelUnit` returns `true` and `feedback` returns `false`
(no-op stubs). Unknown methods answer `FlutterMethodNotImplemented`.

Shared rules:

- **`unitId`** is a Dart-generated UUID identifying one prefetch unit; it lets
  Swift debounce/ignore calls that were cancelled by a mode/flip change and
  lets Dart discard stale answers.
- The response **proposal JSON** is defined by the per-request `@Generable`
  struct ([[AI Challenge Generation]]). It is a *proposal*: the Dart
  [[AI Challenge Validator]] runs before anything reaches the player.
- **Transport format is stable and owned by the Dart side.** The Swift side
  never decides the shape; it fills the schema that Dart's schema registry
  declares. Both sides' schema must be kept in lockstep — enforced by the
  [[Testing and Evaluation]] round-trip tests (a Swift type is not compiled in
  these tests, so the *protocol fixture* is the contract).

The optional `feedback` method maps to `logFeedbackAttachment` (sentiment /
issue / desired-output) so on-device model quality feedback stays on-device —
see [[Privacy and Offline]] and [[Testing and Evaluation]].

## Related

- [[Dynamic AI Director]] — the system overview
- [[AI Challenge Generation]] — what a challenge proposal looks like
- [[Dynamic Profiles and Tool Calling]] — profiles and tool calls
- [[Performance and Resource Budgets]] — latency/temperature/context budgets
- [[Feature Flags]] — AI Experience Modes and how availability feeds them