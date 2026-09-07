---
tags: [ai, privacy, offline]
updated: 2026-09-07
---

# Privacy and Offline

Where every byte of the AI feature lives. The model asks questions about
*the game state a player chose to play* — nothing else — and nothing it learns
or produces ever leaves the device.

## The ground rules

- **The feature is fully on-device.** [[Foundation Models Integration]] runs
  entirely through Apple's on-device `FoundationModels` (the
  `ays/apple_intelligence` MethodChannel touches nothing but the local
  process). There is no network call for generation, no server, no analytics
  endpoint.
- **The app adds no permissions, no keys, no sign-in.** iOS has nothing to
  grant for this; the AI feature needs no entitlement beyond what the game
  already has.
- **Generation fails closed.** If the model cannot answer on-device, the
  round is scripted ([[Pre-generation Cache]] invariant). Offline (no
  network) has zero effect on the AI feature — on-device models don't need
  one; and a device in airplane mode plays the full game either way.
- **`SystemLanguageModel.default.availability == .available` is the only
  "enable" signal** for the machine; everything else on top is the player's
  Settings choice ([[Feature Flags]]).

## What enters a prompt

Only **aggregates and enums**, never identifiers:

| Allowed into a prompt | Never allowed |
|---|---|
| `mostCommonMistakeCategory` (enum from [[Player Telemetry and Adaptive Difficulty]]) | names, contact, location, identifiers |
| per-mechanic success rates **rounded to 10 %** | raw tap logs, raw reaction times beyond the rounded average |
| `fastestStreak`, current `level`, `streak`, `bestLevel`, `locale` ([[Dynamic Profiles and Tool Calling]] facade) | device model / serial / advertising ID |
| multiplayer anonymous role scores (no names) | chat or anything other players typed |

The truncation facade (`ProfileForPrompts`) exists so the *shape* of a prompt
is that small fixed set of fields — a reviewed, stable contract from
[[Dynamic Profiles and Tool Calling]] — not "whatever the profile struct
happens to contain".

## What's persisted

- `ayu.row` profile ([[Player Telemetry and Adaptive Difficulty]]) — up to
  ~2 KB, rolling 50-round window, no identity. Cleared by a Stats reset.
- `ayu.*` feature-flag keys and `ayu.dynamicAI.mode` ([[Feature Flags]]).
- **Nothing else.** No transcript of prompts, no "AI history", no cache of
  generated content survives an app termination.

## Observability (local, opt-in, and it stays local)

An internal, debug/QA-only counter block (`ays.ai.observability.*`) records:
unit outcomes (`challengesGenerated`, `challengesValidated`,
`challengesServed`, `regenerations`, `failuresByReason`) and
`averageGenerationMs`. It powers a dev-only "AI quality" screen used in
[[Testing and Evaluation]] playtests. It is **not** an analytics pipeline; it
never leaves the process, is gated by `aiObservabilityEnabled`, and is wiped
by a Stats reset. The project has no analytics integration by design
([[Game Design Pillars]] → offline-only).

## Deleting it all

- Settings → RESET STATS — wipes the profile, the flags revert to shipped
  defaults, observability counters reset.
- Uninstall — everything above lives in app container prefs; deleting the app
  removes it all. There is nothing server-side to delete because there is no
  server.

## Related

- [[Foundation Models Integration]] — the on-device contract
- [[Player Telemetry and Adaptive Difficulty]] — what the profile holds
- [[Dynamic Profiles and Tool Calling]] — the facade / tool bounds
- [[Feature Flags]] — the local switches
- [[State and Persistence]] — the `ayu.*` key inventory