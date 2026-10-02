---
tags: [product, virality, social]
updated: 2026-10-02
---

# Virality and Sharing

The game is designed to be **screen-recorded vertically** and posted.

## The clip

A watchable clip needs: a huge readable instruction, a full-screen color verdict
and a big number at the end. That is exactly the three-beat structure of a run:

1. instruction (46 pt, auto-fit, uppercase)
2. green `YES` / red `ROAST` full-screen flash
3. Game Over card: `LEVEL 27` at 92 pt

Never add UI chrome that steals space from those three.

## The Game Over card

```
ARE YOU STUPID?                     GAME OVER
COME ON.                     ← verdict headline
┌───────────────────────────────┐
│ I REACHED                     │
│ LEVEL 27        (counts up)   │
│ [NEW PERSONAL BEST!] [🔥 STREAK 5] │  (or BEST: LEVEL 31)
└───────────────────────────────┘
┌ KILLED BY ────────────────────┐
│ “TAP THE RED ONE”             │
│ IT WAS ORANGE.                │
└───────────────────────────────┘
[TRY AGAIN] [CONTINUE] [SHARE] [HOME]
```

Designed to survive being cropped to a thumbnail. The **KILLED BY** card is
the joke the screenshot travels on: the stupidly simple instruction that
beat you, plus the challenge's own fail line. The headline is the static
Game Over roast, or — with AI on and the model ready — a verdict written
from the run's facts ([[AI Commentary]] → `gameOver`), indistinguishable in
form. The old "CAN YOU BEAT ME?" + invented viral stat ("most people die at
level 14") was dropped from the card and deliberately left empty — see
[[Decision Log]]. The streak chip only shows from 3 up (same threshold as the in-game
🔥). The whole middle block sits in one `FittedBox(scaleDown)`, so long
headlines or fail lines shrink on short screens instead of overflowing; the
entrance (fade-up beats + level count-up) finishes inside the 600 ms input
lock.

## Share text

`ShareManager.resultText()`:

```
I reached Level 27 in ARE YOU STUPID?
Can you beat me?
```

Plus `(my best: Level 31)` when relevant, plus the game's landing page
(`ShareManager.landingUrlFor(locale)` — the Italian page for `it`, the `/en`
page for every other locale; the same pages Settings opens as "ABOUT THE
GAME"). A web page rather than a store link on purpose: a result shared from
an iPhone is often opened on an Android phone and vice versa, and one page
can link both stores. **That page must carry App Store and Google Play
badges once the listings are live** ([[Release Checklist]]).
`resultText()`/`shareResult()` take the player's `AppLocale` and render this
in their language — see [[Localization]].

Goes through the OS share sheet (`share_plus`). No account, no link shortener,
no tracking.

## Challenge prompts

`lib/data/viral_prompts.dart`, shown every 12 levels and on the Game Over
card. The six lines (translated per language under `viral.*` in
`lib/i18n/strings_*.dart` — [[Localization]]), in English:

- CAN YOU BEAT YOUR FRIEND?
- SEND THIS TO SOMEONE WHO THINKS THEY'RE SMART.
- YOUR FRIEND PROBABLY WON'T PASS LEVEL 20.
- MOST PEOPLE DIE AT LEVEL 14.

**Do not show these after every level.** Frequency is controlled by
`Difficulty.showViralPrompt()`; nagging kills the joke.
