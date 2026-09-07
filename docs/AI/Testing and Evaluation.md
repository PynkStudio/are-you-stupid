---
tags: [ai, testing]
updated: 2026-09-07
---

# Testing and Evaluation

How a feature that *cannot* run its real model in CI stays trustworthy. All
AI logic is pure-Dart by design so it is testable headless; the Swift side is
type-checked and the *bridge* is mocked.

## Test layout (`test/ai/`)

| Suite | What it verifies | Runs where |
|---|---|---|
| `validator_test.dart` | Every [[AI Challenge Validator]] rule, both sides (valid passes, each rule flips to the right verdict); determinism (`same input ⇒ same verdict`; property test over seeds); regeneration keeps *exactly one* retry | CI, `flutter test` |
| `cache_test.dart` | [[Pre-generation Cache]] invariants: no served invalid, no regen in input path, underflow ⇒ scripted, cancellation, stale-key eviction, exhaustion economics (≤ 1 in-flight, ≤ 1 regeneration) | CI |
| `provider_test.dart` | `FallbackChallengeProvider`/`AdaptiveChallengeProvider` composition, territory/flag logic, rollback to scripted on every unit outcome | CI |
| `telemetry_test.dart` | Mistake classification per category; rolling-window math; EMA; reset-on-`RESET STATS`; `ProfileForPrompts` truncation (nothing out of the allowed field set) | CI |
| `flags_test.dart` | Tri-state matrix: every 3^6 combination yields a valid *posture* (never a served-unvalidated round, never a blocking path); mode ↔ flag mapping | CI |
| `bridge_contract_test.dart` | Dart side of the `ays/apple_intelligence` contract: argument shapes, `proposal` envelope parsing, `error` mapping to fallback verdicts ([[Foundation Models Integration]]) | CI, **with `MockAppleAIService`** |
| `widget_flow_test.dart` | One widget test running a full match with the mock bridge: AI challenge served mid-run, silent fallback mid-run, mode switch mid-session ([[Dynamic AI Director]]), no error UI ([[Error States and Failure Communication]]) | CI |
| `multiplayer_test.dart` | New wire messages ([[Multiplayer AI Director]]): `aiCapabilities`/`aiDirectorAssignment`/`aiChallengeRound`/`aiCommentary` parsing, deterministic re-validation across "peers", Director Host failover to scripted | CI, harness goldens |

The existing `flutter test` gate ([[Testing]]) stays green at every step —
the AI suites are additive, and Phase 1's provider refactor must keep the
scripted engine test suites passing *unchanged*.

## Environment strategy (no real model in CI)

- **No simulator or CI device can run `FoundationModels` generation.** The
  Swift code is `swiftc -typecheck`-verified in CI (compiles against the
  iPhoneOS 26 SDK surface, [[Foundation Models Integration]]); runtime
  behavior is exercised via the **`MockAppleAIService`**, an in-process Dart
  fake that replays recorded `proposal` envelopes (valid, invalid, failure,
  refusal, timeout) from fixtures.
- The mock is the single seam the widget/bridge tests use; the *real* Swift
  service is only ever linked on-device.
- **Offline/manual harness:** a dev Settings-screen "AI test" panel (flag
  `aiObservabilityEnabled`) runs a fixed fixture battery and prints the local
  observability counters ([[Privacy and Offline]]) so a real-device session
  produces comparable numbers without any telemetry leaving the phone.

## Evaluation (playtest gates)

1. **Blind style check.** A short playtest (internal + small external group)
   answers "did every round feel like the game?" with the AI flag hidden.
   Pass = ≥ 80 % "yes". Guards [[AI as Playing Style]].
2. **Never-blocks check.** Instrumented session asserts max engine-side wait
   for a challenge is `< 1 frame` over a full run (mostly scripted underflow
   by design, [[Performance and Resource Budgets]]).
3. **Validator fairness.** Share of served AI challenges vs *rejected*
   candidates per profile stays in a documented band; absurd rejection debt
   (model can't produce valid content for a whole territory) is itself a
   feature flag trigger back to scripted ([[Feature Flags]]).
4. **Rollout discipline.** AI ships only after suites 1–3 pass on a real
   device with the model actually available. Until then it's off
   ([[Feature Flags]] → rollback ladder).

## Related

- [[AI Challenge Validator]] — the rules the suites lock in
- [[Pre-generation Cache]] — the invariants tested as contracts
- [[Foundation Models Integration]] — the mock surface & error mapping
- [[Testing]] — the repo's existing test gate this builds on
- [[Multiplayer Development]] — harness goldens the AI wire tests extend