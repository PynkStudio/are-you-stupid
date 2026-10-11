---
tags: [architecture, ui]
updated: 2026-10-03
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

## Headlines and titles — `BalancedText`

> **Rule.** Any new title or big headline (anything styled with `Ays.title`
> or `Ays.instruction` that is not a live challenge instruction) must use
> `BalancedText`, not a bare `Text` or `FittedBox`. Hard rule 8 in
> [[Game Design Pillars]].

`lib/ui/widgets/balanced_text.dart`. Every screen title and big headline
(home title, Settings, Best score, Game Over roast/verdict, the "killed by"
instruction, correct/wrong flash message, `bigCenterText`, multiplayer
titles, mock ad title) goes through `BalancedText` instead of a bare `Text`.
It applies three rules, in order:

1. **Never split a word.** If the longest word does not fit the width alone,
   the font shrinks until it does — `IMPOSTAZIONI` stays one word instead
   of `IMPOSTAZION / I`.
2. **Respect `maxLines`** (default 2), shrinking further down to
   `minScale` (40 % of the base size). `maxLines: 1` means "fit on one
   line" — used for single-word titles such as Settings and the home title.
3. **Balance the lines.** With the line count fixed, a binary search finds
   the narrowest width that keeps it, so lines come out even:
   `CONGRATULATIONS, / I GUESS`, never `CONGRATULATIONS, I / GUESS`.

It measures with a `TextPainter` using the same `TextScaler` as the
rendered `Text`. By default it reads its width from a `LayoutBuilder`; the
Game Over headline passes `maxWidth` explicitly because it sits under the
card's `FittedBox`. Small label/body copy stays a plain `Text` on purpose.
The layout maths is a pure static (`BalancedText.balance`) so it can be
unit-tested — see [[Testing]].

## Visual language

`lib/ui/theme.dart` — one palette, one type scale, zero assets:

- neutral: near-black background, `Ays.ink` text
- correct: green full-screen flash
- incorrect: red full-screen flash; headline = the challenge's fail line,
  optional italic `aside` under it (single-player AI aside,
  [[AI Commentary]])
- warning: yellow (timer running out, personal best, counters)

Full-screen flashes are what makes the game readable in a 9:16 clip — see
[[Virality and Sharing]].
