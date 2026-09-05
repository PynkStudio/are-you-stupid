---
tags: [architecture, engine]
updated: 2026-09-05
---

# Game Engine

`lib/core/game_engine.dart`

A `ChangeNotifier` that owns one run. It knows nothing about widgets, audio,
storage or ads — it only exposes state and emits events.

## Phases

`GamePhase` in `lib/core/game_state.dart`:

| Phase | Meaning | Exit |
|---|---|---|
| `idle` | menu | `startRun()` |
| `intro` | "READY?" beat | 550 ms |
| `playing` | a challenge is live | pass / fail / timeout |
| `correct` | green flash | 240 ms → next level |
| `wrong` | red flash + roast | 850 ms → `gameOver` |
| `gameOver` | Game Over layer | retry / continue / quit |

Those timings are the whole "no downtime" feel of the game. Do not raise them
without a very good reason — see [[Game Design Pillars]].

## Clock

The engine has no timers. `GameScreen` drives it with a `Ticker`:

```dart
_engine.tick(delta); // delta clamped to 16 ms if a frame hitches or an ad ran
```

Deterministic and trivially testable: tests call `tick()` in a loop.

## ChallengeHost

`GameEngine implements ChallengeHost`, so a challenge calls `host.pass()`,
`host.fail(reason: ...)` or `host.invalidate()` and never touches game state
directly.

- `pass()` also computes the **fast streak**: answering in under 45 % of the
  time limit extends it. That is the "HIGHEST STREAK" stat.
- `fail(reason:)` uses the challenge's own line when it has one (`IMPATIENT.`,
  `TOO MANY.`), otherwise a random line from [[Humor and Roasts]].

## Events

`GameEvent.{runStarted, levelStarted, correct, wrong, gameOver, continued}` are
emitted to listeners. `GameScreen` maps them to sound, haptics and score
persistence. Nothing else may listen for gameplay purposes.

## Continue

`continueRun()` resumes the *same* level and flips `continueUsed`. The UI only
offers it once per run, and only behind a rewarded ad — see
[[Monetization and Ads]].
