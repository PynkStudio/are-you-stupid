---
tags: [architecture, engine]
updated: 2026-10-02
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
| `wrong` | red flash + roast | 2.85 s → `gameOver`, or instantly on `skipWrongFlash()` |
| `gameOver` | Game Over layer | retry / continue / quit |

`correct` stays tiny on purpose — that's the "no downtime" feel. `wrong` is
long enough to actually read the roast (it used to be 850 ms, too fast to
read — see [[Decision Log]]), but a tap anywhere on the flash calls
`GameEngine.skipWrongFlash()`, which jumps straight to `gameOver` — so a
player who already knows why they lost isn't stuck waiting either. Do not
shorten `wrong` back down, or remove the skip, without a very good reason —
see [[Game Design Pillars]].

### Skip grace

`skipWrongFlash()` is ignored for the first `wrongFlashSkipGrace` (500 ms)
of the wrong flash. Without it, the next tap of a player mashing a
tap-N-times challenge skipped the roast unread (breaking "every failure is
explainable in one line") and could land on a Game Over button.
`GameOverView` adds the matching guard on its side: its buttons absorb input
for the first 600 ms after the card appears. See [[Decision Log]].

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

`continueRun()` resumes the *same* level and flips `continueUsed`. It goes
back through the **READY intro beat** (`GamePhase.intro`, 550 ms) instead of
starting the level instantly — a player returning from a 30-second rewarded
ad must not land in a level whose timer is already running. The UI only
offers it once per run, and only behind a rewarded ad — see
[[Monetization and Ads]].

## Pace notes

`_startLevel` also sets `GameState.paceNote` from
`Difficulty.milestoneKey(level)` — a one-off "the game just changed" line
(`FASTER NOW.` at level 4, `NO MORE TIMER.` at level 6) resolved through
`Strings.t` at the engine's current locale, same mechanism as the viral
prompt. See [[Difficulty Curve]] for the levels and copy keys.
