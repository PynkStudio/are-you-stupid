---
tags: [ai, architecture, configuration]
updated: 2026-09-11
---

# Feature Flags

How the AI experience is switched on/off and why the *mode*, not the flag,
is what the player is shown. See [[Foundation Models Integration]] →
Availability ladder for the states that feed this.

**Implementation status:** the data module (`lib/ai/feature_flags.dart`)
landed — every flag below is real, live, and actually read by name
(`aiMultiplayerDirectorEnabled` gates `PartyAiDirector.announceCapabilities`
so an opted-out phone can never be elected — added slightly after the rest
in Phase 8, see the 2026-09-11 [[Decision Log]] entry on how that gap was
caught). It persists a plain `enabled`/`disabled` bool per flag, not the
tri-state described below — `unavailable` is computed by whoever combines
a flag with live `AppleAiAvailability`, not persisted here. The Settings
Ai section (`_AiSection` in `settings_screen.dart`) is real too —
[[Development Plan]] Phase 9.

## The flags (all local)

Each use-case has a **tri-state** (`enabled | disabled | unavailable`). The
feature flag table is a **single Dart `AiFeatureFlags` immutable struct**
mirroring these keys, stored in `ayu.*` prefs ([[State and Persistence]]):

| Flag key | Default | Gates |
|---|---|---|
| `dynamicAIEnabled` | **enabled** | the whole Director (master switch, [[Dynamic AI Director]]) |
| `aiChallengeGenerationEnabled` | enabled | [[AI Challenge Generation]] vs scripted |
| `aiCommentaryEnabled` | enabled | [[AI Commentary]] |
| `aiAdaptiveDifficultyEnabled` | **disabled** | [[Player Telemetry and Adaptive Difficulty]] territory/tension weighting |
| `aiMultiplayerDirectorEnabled` | enabled | [[Multiplayer AI Director]] host election |
| `aiFailoverEnabled` | enabled | silent scripted fallback on unit failure (default behavior; if disabled, a failing unit is *not* served at all — gameplay still never blocks) |
| `aiObservabilityEnabled` | enabled, local-only | internal QA counters ([[Privacy and Offline]] → observability section) |

Rules that make these boring-by-design:

- **No remote configuration.** All flags ship compiled in and are togglable
  only through Settings' Ai section or a debug-only harness. There is no
  network channel to flip a flag ([[Privacy and Offline]]).
- **A flag flip is instant and mid-session-safe.** All reads are snapshots
  read by the Director per event, not cached decisions; flipping
  `aiChallengeGenerationEnabled` from the Settings screen takes effect from
  the very next round (`prefetch` reads state each time).
- **`disabled` ≠ `unavailable`.** A disabled feature shows its normal state
  (e.g. static commentary) with the Ai section visible but off. An
  *unavailable* feature shows "not supported on this device" — the Settings
  entry explains in one line and stays put ([[Error States and Failure Communication]]).
- **A single master `dynamicAIEnabled = false` returns the game to pure
  scripted** — the exact build no AI feature ever modified. This is what the
  rollout & rollback ladder uses ([[Quality Neutrality and Guardrails]] →
  Mitigation & rollback).

## AI Experience Modes (what Settings shows)

Rather than exposing six flags, Settings exposes **one three-position control**:

| Mode | Meaning | Flags it forces |
|---|---|---|
| **Genius** | full experience — AI challenges + commentary (+ adaptive if it's ever enabled) | all `enabled` |
| **Focused** | only the AI that keeps the core intact — commentary stays, generation stays on but *conservative* (random sampling, high-validity territory only) | all `enabled`, but `GenerationOptions` → conservative profile ([[Dynamic Profiles and Tool Calling]]) |
| **Classic** | pure scripted the way it ships today | all `disabled` |

The mode is a *label over the flags*, stored as **`ayu.dynamicAI.mode`**
(`genius | focused | classic`). To players it's a game feel choice, not a
machine room — the Settings copy says exactly what each mode changes and that
switching is instant ([[Error States and Failure Communication]]).

## The ladder → fallback priority

Because every AI path is fallible, the layering is *fixed* and the model can
only ever *augment*:

```
availability says available + flag enabled
   └─ model unit succeeds (validated, in cache)
        └─ DIRECTED candidate served
   └─ model unit fails / unavailable / flag off
        └─ SCRIPTED candidate served (unchanged engine)
```

Single-player and multiplayer use the same ladder
([[Pre-generation Cache]], [[Multiplayer AI Director]]).

## Related

- [[Dynamic AI Director]] — who reads the flags, event-by-event
- [[Foundation Models Integration]] — the availability states that feed them
- [[Quality Neutrality and Guardrails]] — mitigation & rollback ladder
- [[Error States and Failure Communication]] — what Settings says per state
- [[State and Persistence]] — the `ayu.*` keys this persists