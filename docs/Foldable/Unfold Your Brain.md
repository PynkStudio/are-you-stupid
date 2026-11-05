---
tags: [foldable, gameplay, product]
updated: 2026-11-05
---

# Unfold Your Brain

**ARE YOU STUPID?! — UNFOLD YOUR BRAIN** is the hardware-aware extension of
the solo game for foldable iPhones (Apple's iPhone Duo). Not a separate app,
not a separate mode: on a phone whose hinge reports, five extra challenges
join the normal run. On every other device nothing changes.

> **The phone isn't your controller. The phone is the puzzle.**

Status: **all five challenges pass against the real hinge on Apple's iPhone Duo
simulator; never run on physical hardware**, and no full run has reached them in
real play yet. Measurements are in [[Foldable Hardware Capabilities]]. Work lives
on `feature/iphone-duo`.

## Design

Same pillars as the base game ([[Game Design Pillars]]): one short uppercase
instruction (< 8 words), an unexpected solution, a one-line fail reason,
fast feedback. The physical twist:

- Some rounds need the hinge, some need the screen, and some *look* like they
  need the hinge but don't (DO NOT OPEN: the right move is nothing).
- Hardware rounds never appear in levels 1–3, never back to back, and never
  last less than 4.5 s at any speed (`FoldThresholds.minPhysicalRound`).
- The host jokes about the gap between the phone and the player
  ([[#Host]]).

## The five challenges

Source of truth: `lib/challenges/foldable_challenges.dart`. Catalog rows in
[[Challenge Catalog]] → Foldable.

| # | Id | Instruction | Solution | Fails on | Lv |
|---|---|---|---|---|---|
| 01 | `bend_over` | BEND OVER. | fold partially — with a real angle, 80°–150° | any tap; timeout | 4 |
| 02 | `dont_open` | DO NOT OPEN. | wait, starting closed; a huge OPEN button begs | opening past 30°; pressing OPEN | 4 |
| 03 | `crack_the_code` | FIND THE RIGHT ANGLE. | hold a secret hinge angle (± 14°) for 0.6 s — or, status-only, the other open state for ~1 s | tapping the safe; timeout | 7 |
| 04 | `other_side` | THE ANSWER IS ON THE OTHER SIDE. | switch display configuration to reveal the missing digit, then tap that code | guessing before switching (even if right); wrong code; timeout | 7 |
| 05 | `open_your_mind` | OPEN YOUR MIND. | half-open: the brain names the real shape; tap it *while half open* | the decoy shown when fully open; the right shape while fully open | 8 |

Each declares its requirement and starting state (e.g. DO NOT OPEN only
starts from a closed phone; BEND OVER never from an already half-folded one).
Success lines from the brief are each challenge's `successQuip`, shown on
the **next** round's header (purple mono line) so a long joke is read
without stretching the 240 ms correct flash ([[Game Engine]] → Host quips).

### Fallbacks

- **Status-only hardware**: BEND OVER accepts any `partiallyOpen`; CRACK THE
  CODE switches to its state-based variant. OPEN YOUR MIND only ever uses status.
- **Hinge disappears mid-round** (`hingeUnavailable`): the round **skips**
  (a pass with the SKIPPED note) — never the player's fault, never a lost run.
- **No hinge at all**: templates are filtered out; there is no "non-foldable
  variant" of these five because the classic catalog already covers the same
  tricks (patience, misdirection) without hardware.

## Host

`lib/ai/foldable_commentary.dart` tracks each round — expected interaction,
what the player tried (`fold` / `display` / `tap` / `nothing`), time taken,
opens/closes, hardware fails this run — and feeds the **existing** pipeline:

- **Wrong-flash aside**: a scripted hardware joke when one fits (flapping the
  hinge, tapping instead of folding, folding during a classic round, "the
  hinge got it, you didn't"); otherwise the usual AI aside. The challenge's own
  fail line stays the headline.
- **Game Over verdict**: the round's facts are merged into `RunSummary` for
  the on-device model via the same validated, fallback-first
  `CommentaryProvider` ([[AI Commentary]]). No new AI service, no await on
  the hot path. Pools: `fold.host.*` in all six locales ([[Humor and Roasts]]).

## Safety

Hardware interactions must never encourage damage. By construction:

- no challenge needs force, speed, repeated folding, or the hinge's extremes
  (safe combinations stay within 100°–160°; tolerances are generous);
- two physical rounds never run back to back;
- every threshold lives in `FoldThresholds` (configurable, one place);
- the round skips if the hinge stops reporting.

## Known limitations

- **Never tested on physical foldable hardware.** No claim of device
  compatibility is made.
- Thresholds are tuned to Apple's simulator; real hinge values may differ.
- The inner display is landscape, and the game follows. Every round's layout is
  tested there, and Home and Game Over were checked by eye, but Settings,
  Stats and Multiplayer were not.
- A Split View size change also reveals THE OTHER SIDE's digit.
- A fold kept the Flutter scene running on the simulator. If a real device
  suspends rendering, the clock clamps the gap (`GameEngine.safeDelta`), so no
  round is eaten.
- Solo only. Multiplayer and iMessage are excluded on purpose ([[Decision Log]]).
- No dedicated SFX; the existing correct/wrong cues and a light haptic tick
  on safe "warmer" steps are reused.

## Roadmap

1. Play a full run on Apple's simulator until the rounds come up naturally,
   then check Settings, Stats and Multiplayer on the inner display.
2. Real-device pass, when one is available.
3. iPhone Duo screenshots for App Store Connect.
4. More rounds (tabletop posture, "close it halfway, then tap the top half").
5. Optional dedicated generated SFX for the safe.

Related: [[Foldable Architecture]], [[Foldable Simulator]],
[[Foldable Hardware Capabilities]].
