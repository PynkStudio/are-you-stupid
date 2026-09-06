---
tags: [gameplay, challenges, reference]
updated: 2026-09-06
---

# Challenge Catalog

39 templates. Source of truth is `lib/challenges/registry.dart` — **if you add
or change one, update this note in the same commit** ([[Documentation Rules]]).
Everything below is shown in English; the app ships in five more languages —
see [[Localization]] for how each instruction/hint/fail-line is translated.

Legend: **Lv** = first level it can appear · **W** = pick weight ·
★ = starter (allowed in levels 1–3).

## Colors — `lib/challenges/color_challenges.dart`

| Id | Lv | W | What the player sees | The catch |
|---|---|---|---|---|
| `tap_color` ★ | 1 | 1.4 | TAP RED, four honest color buttons | none — this is the hook |
| `dont_tap_color` ★ | 2 | 1.0 | DON'T TAP RED | doing nothing also loses |
| `tap_actual_color` | 4 | 1.2 | TAP BLUE, words and paint disagree | the instruction names a **color** → paint wins |
| `tap_color_moving` | 6 | 1.0 | TAP RED, buttons wobble | aiming, not reading |
| `dont_tap_color_shifting` | 11 | 1.0 | DON'T TAP RED, colors repaint every ~0.4 s | red at *tap time* is what counts |

## Words — `color_challenges.dart` + `word_challenges.dart`

| Id | Lv | W | What the player sees | The catch |
|---|---|---|---|---|
| `tap_the_word` | 5 | 1.2 | TAP THE ONE THAT SAYS BLUE | it names the **text** → the word wins |
| `tap_word_button` | 5 | 1.0 | TAP THE ONE THAT SAYS "DON'T TAP" | reading vs reflex |
| `odd_word_out` | 6 | 1.0 | three colors and a PIZZA | categorisation |
| `opposite` | 7 | 1.0 | TAP THE OPPOSITE OF LEFT | inversion |
| `spell_count` | 9 | 0.9 | TAP THE LETTERS IN "SEVEN" | 7 is right there. It is 5. |
| `tap_unwritten_color` | 15 | 0.8 | TAP THE COLOR NOT WRITTEN | cross-referencing under time |

## Counting — `counting_challenges.dart`

| Id | Lv | W | What the player sees | The catch |
|---|---|---|---|---|
| `tap_number` ★ | 1 | 1.2 | TAP 7 | none |
| `tap_twice` ★ | 2 | 1.0 | TAP TWICE | 1 = fail, 3 = fail, settles 420 ms after the last tap |
| `math` | 5 | 1.0 | TAP 2 + 3 | speed makes people stupid |
| `tap_exactly_n` | 6 | 1.0 | TAP EXACTLY 5 TIMES | same settle rule |
| `count_shapes` | 7 | 1.0 | HOW MANY CIRCLES? | triangles in the soup |
| `spam_taps` | 8 | 1.0 | TAP 8 TIMES. FAST. | pure panic |

## Patience — `patience_challenges.dart`

| Id | Lv | W | What the player sees | The catch |
|---|---|---|---|---|
| `dont_tap` | 4 | 1.2 | DON'T TAP ANYTHING → a huge TAP ME appears | the bait |
| `do_nothing` | 6 | 1.0 | DO NOTHING + a countdown and rising pressure | winning looks like losing |
| `hold_button` | 7 | 1.0 | HOLD THE BUTTON | releasing = fail, never pressing = fail |
| `no_instruction` | 13 | 0.5 | an empty screen | doing nothing is correct |
| `dont_follow` | 16 | 0.45 | DO NOT FOLLOW THIS INSTRUCTION | the paradox — deliberately rare |

## Reaction — `patience_challenges.dart` + `counting_challenges.dart`

| Id | Lv | W | What the player sees | The catch |
|---|---|---|---|---|
| `wait_for_green` | 5 | 1.0 | WAIT FOR GREEN | early tap → "IMPATIENT." |
| `precise_timing` | 9 | 0.9 | TAP AFTER 2 SECONDS, no countdown | shows the error: `+0.13s` |
| `too_fast` | 10 | 0.7 | TAP AS FAST AS POSSIBLE… then "…AFTER THE GREEN LIGHT" | the terms show up 320 ms later |

## Memory — `memory_challenges.dart`

| Id | Lv | W | What the player sees | The catch |
|---|---|---|---|---|
| `remember_color` | 4 | 1.0 | REMEMBER → blackout → TAP THE COLOR | 900 ms to memorise |
| `remember_position` | 8 | 1.0 | one corner lights up | spatial recall |
| `remember_number` | 10 | 1.0 | REMEMBER 47 | near-miss distractors |
| `last_color` | 12 | 1.0 | a burst of colors | only the **last** one counts |

## Perception — `perception_challenges.dart`

| Id | Lv | W | What the player sees | The catch |
|---|---|---|---|---|
| `spot_different` | 5 | 1.0 | four near-identical shapes | delta shrinks with level, never to zero |
| `size_compare` | 5 | 1.0 | TAP THE BIGGEST / SMALLEST | the instruction flips |
| `didnt_change` | 9 | 1.0 | TAP THE ONE THAT DIDN'T CHANGE | tapping before the change fails: "WAIT FOR IT." |
| `fake_buttons` | 11 | 1.0 | six buttons, five are paint | opacity is the tell |

## Tricks — `trick_challenges.dart`

| Id | Lv | W | What the player sees | The catch |
|---|---|---|---|---|
| `tap_nothing_button` | 8 | 1.0 | TAP NOTHING | there is a button labelled NOTHING |
| `left_right_swap` | 8 | 1.0 | TAP LEFT | they swap after ~400 ms; position at tap time wins |
| `tap_in_order` | 9 | 1.0 | TAP 1 THEN 2 THEN 3 | order is enforced |
| `ignore_next` | 12 | 0.8 | IGNORE THE NEXT LINE / TAP RED | obeying loses |
| `rule_flip` | 14 | 1.0 | TAP RED … becomes TAP BLUE mid-round | read twice |
| `tap_reverse_order` | 17 | 0.8 | TAP IN REVERSE ORDER | 3 → 2 → 1 |

## Fairness audit

Every template above resolves on its own timer and every failure has a one-line
explanation the player can read on the red flash. That is enforced by
`test/challenge_templates_test.dart` — see [[Testing]].
