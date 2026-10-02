---
tags: [ai, testing]
updated: 2026-09-15
---

# Testing and Evaluation

How a feature that *cannot* run its real model in CI stays trustworthy. All
AI logic is pure-Dart by design so it is testable headless; the Swift side is
type-checked and the *bridge* is mocked.

## Test layout (`test/ai/`)

| Suite | What it verifies | Runs where |
|---|---|---|
| `challenge_validator_test.dart` | Every [[AI Challenge Validator]] rule, both sides (valid passes, each rule flips to the right verdict); determinism (`same input ⇒ same verdict`); regeneration keeps *exactly one* retry | CI, `flutter test`  ✅ Phase 2 |
| `challenge_proposal_test.dart` | `ChallengeProposal` takeoff → `GeneratedChallenge` landing semantics (envelope, candidate → sealed answer) | CI  ✅ Phase 2 |
| `apple_ai_service_test.dart` | Dart side of the `ays/apple_intelligence` contract with **`MockAppleAIService`**: `available` states/reasons, proposal decode + `decodingFailure`, `ok:false` error→fallback mapping, null/`PlatformException`, bare-boolean `cancelUnit`/`feedback` ([[Foundation Models Integration]]) | CI  ✅ Phase 2 |
| `generated_challenge_runtime_test.dart` | [[AI Challenge Generation]]'s runtime: one behavior group per `mechanic.action` (pass/fail/background-tap/timeout for `tap`/`color_pick`, avoid semantics for `donot_tap`, hold/release for `hold`, completion order for `tap_many`/`tap_sequence`, goal-counting for `tap_until_stop`), plus element→target/layout/duration rendering | CI  ✅ Phase A |
| `feature_flags_test.dart` | [[Feature Flags]]'s tri-state-in-spirit matrix as actually implemented: documented defaults, master-off short-circuits every sub-flag, sub-flags survive a master round trip, persistence, the three modes' exact flag postures, adaptive difficulty surviving every mode switch | CI  ✅ Phase B |
| `commentary_test.dart` | [[AI Commentary]]'s `isCommentaryLineValid` (every rejection rule) and `CommentaryProvider`'s static-bank-first ladder (flag off, unavailable, valid line used + remembered, invalid/duplicate/failed → fallback, caller override) | CI  ✅ Phase 4 |
| `prefetch_loop_test.dart` | [[Pre-generation Cache]]'s generic `PrefetchLoop<T>` primitive: single-read pop, single-in-flight rule, ring-full no-op, null/thrown-error misses, `invalidate()` discarding a stale in-flight result and not blocking a fresh fetch on it | CI  ✅ Phase 5 |
| `provider_test.dart` | `AIChallengeProvider`: cold start, flag/locale/availability gating, a validated proposal reaching the cache, an invalid/failed/malformed one never reaching it, cache-key invalidation on a level-band crossing, a regression test for a real bug found here (a discarded stale fetch must not poison the freshness-dedupe list), and the real `requestChallenge` payload shape (level/tricks/profile/recent/vocabulary) | CI  ✅ Phase 5/6 |
| `profile_for_prompts_test.dart` | `profileForPrompts`' cold-start defaults, 10%-rounding, and that only the four privacy-allowed keys are ever present; `availableMechanicMoves`' trick gating | CI  ✅ Phase 6 |
| `telemetry_test.dart` | Mistake classification per category; rolling-window math; EMA; reset-on-`RESET STATS`; `ProfileForPrompts` truncation (nothing out of the allowed field set) | CI  ✅ Phase 3 |
| `app_flow_test.dart` ("the Ai section shows a mode picker…") | Settings Ai section behavior over `AiFeatureFlags` (Phase B already covers the flag/mode logic itself); the `testWidgets`-vs-bare-`test()` `MethodChannel` gotcha this case surfaced is logged in [[Decision Log]] | CI  ✅ Phase 9 |
| `full_run_with_mock_bridge_test.dart` | One integration test running a full match through the exact production `AdaptiveChallengeProvider` → `FallbackChallengeProvider` → `ScriptedChallengeProvider`/`AIChallengeProvider` composition and a real `GameEngine`: AI challenge served mid-run, silent fallback mid-run, mode switch mid-session ([[Dynamic AI Director]]), no `GameEvent.wrong` and nothing throwing across the whole run — the strongest "no error UI" assertion available, since no in-game AI error event exists at all ([[Error States and Failure Communication]]). Drives real `Challenge` objects directly rather than rendered widget taps (deliberate; see the file's own doc comment and [[Decision Log]]) | CI  ✅ Phase 10 |
| `party_session_ai_test.dart` / `party_ai_director_test.dart` (Dart) + `ProtocolTests.swift` / `AIDirectorTests.swift` (Swift, `tvos/Tests/AYSHostCoreTests/`) | The wire messages ([[Multiplayer AI Director]]): `AI_CAPABILITIES`/`AI_DIRECTOR_ASSIGNMENT`/`AI_ROUND_PROPOSAL`/`AI_CHALLENGE_ROUND`/`AI_COMMENTARY_PROPOSAL`/`AI_COMMENTARY` golden-fixture parsing on both sides, election/re-election determinism, failover to scripted rounds, and the two real bugs a self-review caught before calling Phase 8 done (a missing Director-only gate on outbound commentary, a feature flag defined but never read) | CI, harness goldens  ✅ Phase 7/8 |

Every row above is landed ([[Development Plan]]).

The existing `flutter test` gate ([[Testing]]) stays green at every step —
the AI suites are additive, and Phase 1's provider refactor must keep the
scripted engine test suites passing *unchanged*.

## Environment strategy (no real model in CI)

- **No simulator or CI device can run `FoundationModels` generation.** The
  Swift code is `swiftc -typecheck`-verified against the real iPhoneOS SDK
  surface ([[Foundation Models Integration]]) via `tool/swiftc_ai_gate.sh`
  (skips cleanly when the SDK is absent); runtime behavior is exercised via
  the **`MockAppleAIService`**, an in-process Dart fake that replays recorded
  `proposal` envelopes (valid, invalid, failure, refusal, timeout) from
  fixtures.
- The mock is the single seam the widget/bridge tests use; the *real* Swift
  service is only ever linked on-device.
- **Offline/manual harness:** a dev Settings-screen "AI test" panel (flag
  `aiObservabilityEnabled`) runs a fixed fixture battery and prints the local
  observability counters ([[Privacy and Offline]]) so a real-device session
  produces comparable numbers without any telemetry leaving the phone.

## Evaluation (playtest gates)

**Status: gates 1 and 4 below remain unexercised as of [[Development
Plan]] Phase 10.** Every suite in the table above runs headless against
`MockAppleAIService` — no Apple-Intelligence-capable device has been
available in this environment at any point across Phases 2-10. The whole
pipeline compiles, typechecks against the real SDK
([[Foundation Models Integration]]), and is wired end-to-end, but "does a
real device, with the model actually available, feel right to a human" has
never been checked. This isn't a gap anyone is glossing over: it's the
reason gate 4 exists as a hard gate at all.

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