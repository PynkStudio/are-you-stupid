---
tags: [architecture, ui]
updated: 2026-09-05
---

# Rendering Pipeline

`lib/ui/widgets/challenge_renderer.dart`

The renderer is the **only** place that turns a [[Challenge System|ChallengeView]]
into widgets. It contains no game rules — it cannot decide pass or fail.

```
ChallengeRenderer
├── _InstructionBlock   instruction (auto-shrinks), hint, tap counter
└── _PlayArea
    ├── bigCenterText   (memory number, shape soup, countdown)
    └── layout switch   grid2x2 | grid3 | row | single | none | free
        └── TargetButton per TargetSpec
```

## Layouts

| Layout | Used for |
|---|---|
| `grid2x2` | four huge buttons — the default |
| `grid3` | six buttons (fake buttons) |
| `row` | left/right, two-way comparisons |
| `single` | one giant pad: hold, spam, wait-for-green |
| `none` | nothing to tap, the screen is the target |
| `free` | absolute positions via `TargetSpec.x/y` |

## Background taps

The whole game screen is a `Listener`. A tap on a target fires the target's
handler first (children receive pointer events before ancestors), so the target
sets a flag on `TapClaim` and the background listener skips that event. This is
how "DON'T TAP ANYTHING" can fail on a tap anywhere on screen while
"TAP RED" ignores misses.

## Target rendering

`TargetButton` applies, in order: wobble offset (`dx`/`dy` × constraints),
rotation, press scale (0.94, 70 ms), opacity, then the shape
(rect / circle / triangle / diamond via `CustomPainter`).

Labels use `FittedBox` so a long word never overflows or wraps badly.

## Visual language

`lib/ui/theme.dart` — one palette, one type scale, zero assets:

- neutral: near-black background, `Ays.ink` text
- correct: green full-screen flash
- incorrect: red full-screen flash
- warning: yellow (timer running out, personal best, counters)

Full-screen flashes are what makes the game readable in a 9:16 clip — see
[[Virality and Sharing]].
