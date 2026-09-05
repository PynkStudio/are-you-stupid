---
tags: [gameplay, balance]
updated: 2026-09-05
---

# Difficulty Curve

`lib/core/difficulty.dart` — the only place that decides how hard things get.

## Speed

```dart
level <= 3      → 0.85   // deliberately generous, the game must feel free
level > 3       → 1.0 + (level - 3) * 0.042, capped at 2.35
```

Every challenge computes its round length with `params.pace(base)` =
`base / speed`, with a per-challenge floor (`floorMs`) so nothing becomes
physically impossible. Floors are why level 60 is hard but not a coin flip.

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
