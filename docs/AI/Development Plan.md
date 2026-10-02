---
tags: [ai, development, roadmap]
updated: 2026-09-15
---

# Development Plan

The implementation path for the AI feature, phase by phase. It is deliberately
**additive and reversible**: every phase lands while the game ships fully
scripted and the flag ladder ([[Feature Flags]]) can return to pre-AI behavior
in one toggle.

## Fit with the roadmap

This plan is the engineering source for the AI items on [[Roadmap]]. It is
not a product announcement — nothing here implies the feature is shipping in
a release; availability and rollout gates are [[Feature Flags]] +
[[Quality Neutrality and Guardrails]] → Mitigation & rollback.

## Phases

Each phase ends with `flutter analyze` clean and `flutter test` green
([[Testing]]), and the docs updated in the same commit
([[Documentation Rules]]).

### Phase 0 — Documentation branch  ✅ done
Branch `ai/dynamic-director`; full `docs/AI/` set + cross-links; updates to
[[Home]], [[Roadmap]], [[Architecture Overview]], [[Services]], [[State and Persistence]], [[Testing]], [[Getting Started]], [[Documentation Rules]],
[[Decision Log]]. Committed and pushed as the documentation deliverable on its
own (`ai/dynamic-director` on `PynkStudio/are-you-stupid`).

### Phase 1 — Provider seam (no behavior change)  ✅ done
- `lib/ai/` scaffold landed: `ChallengeProvider` seam + `ChallengeContext`
  ([[AI Challenge Generation]]), `GeneratedChallenge`
  (`lib/ai/generated_challenge.dart`), and the three providers in
  `lib/ai/providers.dart` — `ScriptedChallengeProvider` (the existing
  `ChallengeGenerator` logic, unchanged), `AdaptiveChallengeProvider` shell,
  `FallbackChallengeProvider`.
- `lib/core/game_engine.dart` now consumes `ChallengeProvider`
  (`FallbackChallengeProvider(scripted: ScriptedChallengeProvider(...))` in
  `game_screen.dart`); `core/` is source-agnostic.
- The seam is **synchronous by design** — the engine never awaits a model.
  See the 2026-09-07 [[Decision Log]] entry.
- No AI behavior yet — every assertion in the scripted engine suites passes
  unchanged (three `GameEngine` constructions got the one-line wrap).

### Phase 2 — GeneratedChallenge + validator + native bridge  ✅ done
- `ChallengeProposal` (portable wire model) + `GeneratedChallenge` (built,
  playable) both in `lib/ai/generated_challenge.dart`; `ChallengeMechanic`
  closed vocabulary + 9-mechanic registry in `lib/ai/challenge_vocabulary.dart`
  ([[AI Challenge Generation]]).
- `ChallengeValidator` ([[AI Challenge Validator]]) — pure Dart, sealed
  verdicts, its own suite (`test/ai/challenge_validator_test.dart`).
- `AppleAIService` (Dart) + `ays/apple_intelligence` MethodChannel
  ([[Foundation Models Integration]]); `MockAppleAIService` and wire-contract
  tests (`test/ai/apple_ai_service_test.dart`).
- Swift side (`ios/Runner/AppleAIService/`): `@Generable` `AYSChallengeProposal`
  schema + availability rail over `SystemLanguageModel`, channel registered in
  `AppDelegate`; generation calls stubbed with `notImplemented` until Phases
  4–5. `tool/swiftc_ai_gate.sh` typechecks it against the real FoundationModels
  SDK at the iOS 15 target.
- See the 2026-09-07 [[Decision Log]] entries (proposal/envelope split,
  trick-contract interpretation, `@Generable` limitations).

### Phase 3 — Telemetry + adaptive difficulty  ✅ code done, not wired into production
- `TelemetryCollector` + `PlayerGameplayProfile` ([[Player Telemetry and Adaptive Difficulty]]), `ayu.profile` persistence, mistake classifier.
- `AdaptiveChallengeProvider` is fully built and tested but never constructed
  in `game_screen.dart` — wiring it into production is folded into Phase 5
  below (it needs to land alongside the flags that gate it).

### Phase A — Generated Challenge Runtime (not in the original numbering)  ✅ done
- `lib/ai/generated_challenge_runtime.dart` — the piece the doc's shape
  descriptions assumed but nothing built: turns a validated
  `ChallengeProposal` into an actual playable `Challenge` (tap/hold/sequence
  judging per `mechanic.action`). Required before Phase 4 or 5 can do
  anything real with a generated proposal. See the 2026-09-11 [[Decision
  Log]] entry for the per-mechanic interpretation calls.

### Phase B — `AiFeatureFlags` data module (not in the original numbering; pulled forward from Phase 9)  ✅ done
- `lib/ai/feature_flags.dart` — every flag from [[Feature Flags]] plus
  `AiExperienceMode`, `SharedPreferences`-backed, live from today so Phases
  4-8 read real gating instead of being retrofitted later. Only the
  Settings UI screen stays in Phase 9's slot below. See the 2026-09-11
  [[Decision Log]] entry.

### Phase 4 — Commentary  ✅ done, not wired into live gameplay yet
- Commentary kinds + per-kind contracts ([[AI Commentary]]); AI service
  `requestCommentary`; static-bank-first ladder.
- `lib/ai/commentary.dart` (`CommentaryKind`, `isCommentaryLineValid`,
  `CommentaryProvider`) + real Swift `AYSCommentaryService`
  (`ios/Runner/AppleAIService/CommentaryProfile.swift`), verified against
  the real iPhoneOS 26.5 SDK in this environment. `CommentaryProvider.line()`
  is async, so it isn't called from `GameEngine.fail()`/`.pass()` yet —
  that needs Phase 5's synchronous cache pop. See the 2026-09-11
  [[Decision Log]] entry.

### Phase 5 — Pre-generation cache  ✅ done (challenge ring; commentary ring deferred to Phase 8)
- `PrefetchLoop` (generic, `lib/ai/prefetch_loop.dart`), the challenge ring
  backing a real `AIChallengeProvider`, wired into `game_screen.dart`'s
  `FallbackChallengeProvider.ai` slot for the first time — the game is no
  longer unconditionally 100% scripted in production (though real
  generation itself is still `notImplemented` on the Swift side, so it
  stays scripted in practice until that lands too). `AdaptiveChallengeProvider`
  also wired into production, behind its own default-off flag. The
  commentary ring (`commentaryByKind`) isn't wired to a live consumer yet —
  no `cancelUnit`/SLA-timer work landed either, since nothing is far enough
  along yet to need real timeout enforcement beyond "the ring is empty."
  See the 2026-09-11 [[Decision Log]] entry (including a real dedupe bug
  found and fixed while testing this).

### Phase 6 — Profiles + tool calling  ✅ done (`ChallengeGenerationProfile`; other profiles' tools not needed yet)
- `@Guide` annotations across every `AYSChallengeProposal` field
  (`ChallengeProposal.swift`); real `requestChallenge`
  (`ChallengeGenerationProfile.swift`) with a hand-built wire dict (no
  `Encodable` from `@Generable`) and a canonical English fail-line table;
  three snapshot-backed `Tool` conformances (`GenerationTools.swift`) —
  deliberately not a live Dart↔Swift tool bridge, since `requestChallenge`'s
  existing `profile` argument already carries everything they need. Dart
  side: `lib/ai/profile_for_prompts.dart` (the truncation facade),
  `availableMechanicMoves()`, and `AIChallengeProvider` sending a real
  payload instead of just `{unitId, locale}`. `CommentaryProfile`/
  `FinalRoundProfile`/`MultiplayerHostProfile`'s own tool sets aren't built
  yet — no caller needs them (final-round and multiplayer-director are
  later work). See the 2026-09-11 [[Decision Log]] entry.

### Phase 7 — Multiplayer messages  ✅ done (plumbing only)
- Six wire kinds, not four — `AI_CAPABILITIES`, `AI_DIRECTOR_ASSIGNMENT`,
  `AI_ROUND_PROPOSAL`, `AI_CHALLENGE_ROUND`, `AI_COMMENTARY_PROPOSAL`,
  `AI_COMMENTARY` ([[Multiplayer AI Director]] — the doc's four-row table
  conflated "produce" and "relay" into one row); harness goldens
  (26 → 34 lines) on both `protocol.dart` and `ProtocolModel.swift`.
  `party_session.dart`/`RoomHost.swift` dispatch wiring only — no election,
  no relay behavior, no round actually opened from `AI_CHALLENGE_ROUND` yet.
  See the 2026-09-11 [[Decision Log]] entry.

### Phase 8 — Host election + failover  ✅ done
- Election (`RoomHost.electDirector`), a single-slot pending-proposal relay
  (`startNextRound`/`startAiRound`), failover on the Director's seat being
  removed, and the Dart-side `PartyAiDirector` runtime that actually
  generates and sends rounds/commentary. Commentary display in the UI is
  the one deliberate scope cut — captured (`HostViewModel.lastAiCommentary`)
  but not yet shown anywhere, same reasoning as single-player's own Phase 5
  deferral. See the 2026-09-11 [[Decision Log]] entry.

### Phase 9 — Feature flags UI  ✅ done
- The data module (`AiFeatureFlags` + `AiExperienceMode`) landed early as
  Phase B above. This phase: the Settings Ai section (`_AiSection` in
  `settings_screen.dart`) — the mode picker + per-device availability copy
  ([[Error States and Failure Communication]]), translated into all six
  locales. See the 2026-09-11 [[Decision Log]] entry (including a real
  `testWidgets`-vs-`test()` MethodChannel gotcha found while testing it).

### Phase 10 — AI test suites + evaluation gates  ✅ done (the parts an Apple-Intelligence-free environment can exercise)
- `test/ai/full_run_with_mock_bridge_test.dart`: the "full match with mock
  bridge" case — the exact `AdaptiveChallengeProvider` →
  `FallbackChallengeProvider` → `ScriptedChallengeProvider` +
  `AIChallengeProvider` composition `game_screen.dart` builds, driven
  through a real `GameEngine` run. Covers AI served mid-run, an invalid
  proposal falling back to scripted silently, a mid-session
  `aiChallengeGenerationEnabled` flip taking effect on the very next round,
  and — across every round, starter or not — no `GameEvent.wrong` ever
  firing and nothing throwing (there is no in-game "AI error" event to
  surface in the first place, see [[Error States and Failure
  Communication]]). Writing it caught a real gap: `AIChallengeProvider`
  had no `Difficulty.isStarter` gate, so an AI proposal could have been
  served as early as level 1, breaking CLAUDE.md's "levels 1-3 stay
  trivial" pillar — fixed, with its own regression group in
  `provider_test.dart`. See the 2026-09-15 [[Decision Log]] entry.
- The blind-playtest and real-device evaluation gates ([[Testing and
  Evaluation]], items 1 and 4) remain **unexercised** — no
  Apple-Intelligence-capable hardware is available in this environment,
  the same limitation every phase since Phase 2 has carried forward
  honestly rather than glossed over.

## Dependencies

- Phase 1 is prerequisite-free (self-contained refactor).
- Phases 2–4 depend on Phase 1's seam; Phase 5 depends on Phase 2;
  Phases 6–8 depend on 2 + 7; Phase 9 depends on 2–6; Phase 10 constantly
  runs in parallel from Phase 2 onward (test suites land with each phase).
- Multiplayer phases are independent of single-player ones and follow the
  [[Multiplayer Development]] conventions (wire determinism, harness).

## Definition of done (feature-level)

- All ten phase suites green; `flutter test` includes the AI suites.
- Real-device smoke passes with the model *actually available*: an
  AI challenge round served, a fallback round served, a mode switch, no
  blocking.
- Docs current (every touched note updated in its commit).
- ~~Nothing is on by default ahead of the evaluation gates~~ — superseded by
  [[Feature Flags]]'s actual shipped defaults (`dynamicAIEnabled` and most
  sub-flags default **enabled**, `aiAdaptiveDifficultyEnabled` default
  disabled): the rollout safety net is the validated/scripted-fallback-first
  pipeline itself, not an off-by-default flag, so the model never touches a
  round the fallback ladder wouldn't also produce a valid one for. The
  evaluation gates below still gate a *store release*, independent of the
  flag defaults.

## Related

- [[Dynamic AI Director]] — the architecture each phase builds on
- [[Testing and Evaluation]] — the gates each phase must pass
- [[Feature Flags]] — how the phases stay reversible
- [[Roadmap]] — product-level view this maps onto
- [[Documentation Rules]] + [[Decision Log]] — every phase is documented