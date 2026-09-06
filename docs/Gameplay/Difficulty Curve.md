---
tags: [gameplay, balance]
updated: 2026-09-06
---

# Difficulty Curve

`lib/core/difficulty.dart` — the only place that decides how hard things get.

## Speed

```dart
level 1         → 0.60
level 2         → 0.73
level 3         → 0.85   // deliberately generous, the game must feel free
level > 3       → 1.0 + (level - 3) * 0.042, capped at 2.35
```

Levels 1–2 ramp *up into* the level-3 value instead of starting there. A
brand-new player's very first round used to run at the same pace as their
third — plenty of time to know the game, not enough to have learned it yet.
Level 3 onward is unchanged from before.

Every challenge computes its round length with `params.pace(base)` =
`base / speed`, with a per-challenge floor (`floorMs`) so nothing becomes
physically impossible. Floors are why level 60 is hard but not a coin flip.

## Timer visibility

`Difficulty.showTimerBar(level)` — the depleting bar (`TimerBar` in
`game_screen.dart`) is visible for levels 1–5 and hidden from level 6 on,
the same level "mean" templates unlock (`allowsTricks`). This is on top of a
challenge's own `showTimer` (memory/patience challenges already hide it for
mechanical reasons — see [[Challenge System]]): once tricks are in the pool,
not knowing how much time is left becomes difficulty too — the last item on
[[Game Design Pillars]]'s "where difficulty comes from" list, deliberately
introduced only after the easier sources (misleading wording, fake buttons,
memory) are already active.

`TimerBar`'s fill is a childless `DecoratedBox` inside a `Row` — it needs
`crossAxisAlignment: CrossAxisAlignment.stretch` or it lays out at zero
height and the bar is invisible on a real device even though `visible` is
`true`. Caught after a real-device report; see [[Decision Log]].

## Pace milestones

`Difficulty.milestoneKey(level)` returns a one-line callout shown once, the
first time that level is reached (`GameState.paceNote`, rendered the same way
as the viral-prompt line below it):

| Level | Key | Why |
|---|---|---|
| 4 | `ui.game.milestone.faster` | speed leaves the flat 0.85 warm-up and starts climbing |
| 6 | `ui.game.milestone.no_timer` | the timer bar above disappears (see previous section) |

Both are translated in all six `strings_*.dart` files like any other UI
string — see [[Localization]].

## Unlocks

Difficulty mostly comes from *which templates exist yet*, not from raw speed:

| Levels | What is in the pool |
|---|---|
| 1–3 | starters only: `tap_color`, `tap_number`, `tap_twice`, `dont_tap_color` |
| 4–7 | conflicts (paint vs word), memory, patience, perception |
| 8–12 | traps: swaps, fake buttons, spam, timing, shifting colors |
| 13+ | paradoxes and rule changes: `no_instruction`, `rule_flip`, `dont_follow` |

See [[Challenge Catalog]] for the exact `minLevel` of each.

## Intra-challenge scaling

Some templates read `params.level` themselves:

- `spot_different` — the visual delta shrinks from 0.22 to ~0.09
- `last_color` — sequence grows from 3 to 5
- `spam_taps` — target count grows with level
- `tap_color_moving` — wobble amplitude grows

## Viral prompts

`Difficulty.showViralPrompt(level)` → every 12th level, one line from
[[Virality and Sharing]]. Rare on purpose.

## Tuning rules

1. Never make level 1–5 harder. The hook is "this is easy".
2. Prefer adding a *template* over raising speed.
3. If a change makes a failure unexplainable, revert it ([[Game Design Pillars]]).
