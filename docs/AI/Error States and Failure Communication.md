---
tags: [ai, errors, ux]
updated: 2026-09-07
---

# Error States and Failure Communication

How availability, failure, and "the model just isn't there" are shown — or
deliberately hidden. The rule: **gameplay never errors** (silent scripted
fallback), while **Settings is honest** about the machine's real state.

## What's silent (by design)

In-game, an AI failure produces **no error UI** — none. No spinner, no
retry toast, no "AI is thinking…" There is no in-game AI state the player can
perceive, because the round they get is always a valid one and the path that
served it (AI or scripted) is invisible to them ([[Quality Neutrality and Guardrails]] → no AI wallpaper).

Failures that are `silent`:

| Situation | In-game surface |
|---|---|
| unit `invalid` / `failureExit` / `regeneration exhausted` | that round = scripted, identical feel |
| `availability != available` | every round = scripted |
| flag flipped mid-session | next round = scripted, this session's cache discarded |
| multiplayer: Director Host lost | match stays on seeded scripted rounds ([[Multiplayer AI Director]]) |
| non-English locale v1 | full scripted path ([[Localization and Language]]) |

There is exactly one in-game exception ever admitted: if the *model unit fails
while the player is waiting* — impossible by construction but worth stating —
the fallback is `scripted`, and the flash system
(GameState.reason, [[Game Engine]]) shows the *scripted* fail line, never an
"AI error" line.

## What's honest (Settings → Ai)

Settings surfaces the machine's *real* posture — because a player who toggles
Ai deserves a truthful two lines, and a player who doesn't, sees nothing.

| State | Settings copy (one line + the mode picker) |
|---|---|
| `available` | "Challenge variety is on for this device." + [[Feature Flags]] mode picker (Genius / Focused / Classic) |
| `supported` but not user-enabled (device-level Apple Intelligence off) | "Your device can do it, but Apple Intelligence is off in their settings." The picker stays visible and interactable; toggling it explains it will fall back until Apple Intelligence is on. |
| `deviceNotEligible` | "Not supported on this device." Picker disabled with that line. |
| `modelNotReady` | "Model download in progress. Classic mode active until it's ready." |

The copy is a **compiled, localized** string set ([[Localization and Language]]) driven by the availability enum (`supported/available` ladder,
[[Foundation Models Integration]]), never by an error object
pretty-printed from the bridge.

## What the developer sees (debug only)

The `FailureCommunication` vocabulary (`equipmentUnavailable`,
`generationFailed`, `refused`, `gracefulDegradation`, `unreachable` claim) is
a **log/observability classification**, gated behind `aiObservabilityEnabled`
([[Privacy and Offline]]), recorded locally, and surfaced only in the dev "AI
quality" screen. No failure string from that vocabulary is ever rendered in
a shipped UI. This keeps the error taxonomy rich for fixing, while the
player-facing surface stays exactly two honest lines in Settings.

## Related

- [[Foundation Models Integration]] — error → fallback mapping
- [[Feature Flags]] — modes the Settings picker drives
- [[Localization and Language]] — the localized Settings strings
- [[Quality Neutrality and Guardrails]] — no on-screen AI wallpaper
- [[Testing and Evaluation]] — error-state golden cases