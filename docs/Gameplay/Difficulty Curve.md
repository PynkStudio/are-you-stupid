---
tags: [gameplay, balance]
updated: 2026-09-08
---

# Difficulty Curve

`lib/core/difficulty.dart` — the only place that decides how hard things get.

## Speed

A **stepped** multiplier, not a continuous formula — the whole point is that
a level never feels faster than the one before it just because the level
number ticked up by one. Every challenge computes `params.pace(base,
floorMs: min)` = `base / speed`, clamped to `min`. That makes `base` the
*most* time a given challenge template ever grants (reached at level 1-2)
and `floorMs` the *least* (approached only at the highest levels) — every
template already carries both numbers, one per call site in
`lib/challenges/*.dart`.

```dart
level 1-2   → 0.49   // the most generous the game ever is
level 3-4   → 0.52
level 5-6   → 0.56
level 7-9   → 0.65   // tutorial's over, still calm
level 10-19 → 0.82   // "alive" starts here
level 20-29 → 1.05
level 30-39 → 1.29
level 40-49 → 1.52
level 50+   → 1.76   // asymptote — well under the old formula's 2.35 cap
```

**Levels 1-9 are the tutorial.** Nine levels, five gentle steps, each one a
small nudge rather than a jump — a new player should never feel the game
"snap" faster from one round to the next while they're still learning it.
**Level 10 is where the game starts feeling alive**, and from there it steps
every ten levels, same shape as the tutorial steps but bigger, until it
settles at 1.76 — deliberately short of the old formula's 2.35 ceiling, so
even the endgame stays a little more generous than it used to be.

**Why steps and not a formula.** A continuous curve (the old
`1.0 + (level - 3) * 0.042`) makes *every single level* a little different
from the last, which is exactly the "feels like it's constantly speeding up"
sensation that prompted this rewrite. Flat steps mean a run of levels feels
consistent, then visibly changes gear — a much easier thing for a player to
notice and adapt to than a slope.

**Heavier challenges get their own boost on top.** `math`, `spell_count`,
`count_shapes`, `tap_exactly_n` and `opposite` need actual thought (an
arithmetic problem, counting a soup of shapes, counting letters, recalling
an antonym) rather than a glance-and-tap — their `base`/`floorMs` were bumped
independently of the table above, so they carry more time than a
same-difficulty color tap at every level, not just at the start. This didn't
need a new mechanic: `pace()` already took a per-challenge base and floor,
it's just that most of them had never been tuned to reflect "this one takes
longer to *think*."

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

`TimerBar` renders its fill with an explicit pixel width/height (via
`LayoutBuilder` + `Container`), not a `Row`/`Expanded` flex ratio — a
flex-sized childless `DecoratedBox` turned out to lay out at zero height on
a real device despite `visible` being `true`. Caught (and re-caught, in a
different shape) from real-device reports; see [[Decision Log]].

## Pace milestones

`Difficulty.milestoneKey(level)` returns a one-line callout shown once, the
first time that level is reached (`GameState.paceNote`, rendered the same way
as the viral-prompt line below it):

| Level | Key | Why |
|---|---|---|
| 6 | `ui.game.milestone.no_timer` | the timer bar above disappears (see previous section) |
| 10 | `ui.game.milestone.faster` | the tutorial ends and speed starts stepping up every ten levels |

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
