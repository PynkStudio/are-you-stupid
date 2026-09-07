---
tags: [ai, development, roadmap]
updated: 2026-09-07
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

### Phase 0 — Documentation branch  ✅ in progress
Branch `ai/dynamic-director`; full `docs/AI/` set + cross-links; updates to
[[Home]], [[Roadmap]], [[Architecture Overview]], [[Services]], [[State and Persistence]], [[Testing]], [[Getting Started]], [[Documentation Rules]],
[[Decision Log]]. Commit and push the *documentation deliverable* on its own.

### Phase 1 — Provider seam (no behavior change)
- `lib/ai/` scaffold: `ChallengeProvider` interface ([[AI Challenge Generation]]), `ScriptedChallengeProvider` (the existing
  `ChallengeGenerator` logic, unchanged), `AdaptiveChallengeProvider` shell,
  `FallbackChallengeProvider`.
- `lib/core/` stops knowing about source: engine consumes `ChallengeProvider`.
- No AI behavior yet — scripted engine test suites pass unchanged.

### Phase 2 — GeneratedChallenge + validator + native bridge
- `GeneratedChallenge` model + `ChallengeMechanic` vocabulary
  ([[AI Challenge Generation]]).
- `ChallengeValidator` ([[AI Challenge Validator]]) — pure Dart, its own
  test suite.
- `AppleAIService` (Dart) + `ays/apple_intelligence` MethodChannel
  ([[Foundation Models Integration]]); Swift `@Generable` `ChallengeProposal`
  + `respond(schema:)`; `swiftc -typecheck` gate.

### Phase 3 — Telemetry + adaptive difficulty
- `TelemetryCollector` + `PlayerGameplayProfile` ([[Player Telemetry and Adaptive Difficulty]]), `ayu.profile` persistence, mistake classifier.

### Phase 4 — Commentary
- Commentary kinds + per-kind contracts ([[AI Commentary]]); AI service
  `requestCommentary`; static-bank-first ladder.

### Phase 5 — Pre-generation cache
- `PrefetchLoop`, buffer rings, cancellation (`cancelUnit`), SLA
  ([[Pre-generation Cache]], [[Performance and Resource Budgets]]).

### Phase 6 — Profiles + tool calling
- Swift multi-profile sessions + tool bridge
  ([[Dynamic Profiles and Tool Calling]]).

### Phase 7 — Multiplayer messages
- `aiCapabilities` / `aiDirectorAssignment` / `aiChallengeRound` /
  `aiCommentary` wire kinds ([[Multiplayer AI Director]]); harness goldens.

### Phase 8 — Host election + failover
- Election + heartbeat failover, scripted during the gap.

### Phase 9 — Feature flags & modes
- `AiFeatureFlags` tri-state + AI Experience Modes + Settings Ai section
  ([[Feature Flags]], [[Error States and Failure Communication]]).

### Phase 10 — AI test suites + evaluation gates
- `test/ai/` suites + `MockAppleAIService` ([[Testing and Evaluation]]); blind playtest + never-blocks instrumentation gates.

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
- Nothing is on by default ahead of the evaluation gates.

## Related

- [[Dynamic AI Director]] — the architecture each phase builds on
- [[Testing and Evaluation]] — the gates each phase must pass
- [[Feature Flags]] — how the phases stay reversible
- [[Roadmap]] — product-level view this maps onto
- [[Documentation Rules]] + [[Decision Log]] — every phase is documented