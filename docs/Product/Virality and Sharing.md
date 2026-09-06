---
tags: [product, virality, social]
updated: 2026-09-06
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
ARE YOU STUPID?
COME ON.
I REACHED
LEVEL 27
NEW PERSONAL BEST!   (or BEST: LEVEL 31)
CAN YOU BEAT ME?
```

Designed to survive being cropped to a thumbnail.

## Share text

`ShareManager.resultText()`:

```
I reached Level 27 in ARE YOU STUPID?
Can you beat me?
```

Plus `(my best: Level 31)` when relevant, plus `ShareManager.storeUrl` once the
app is live — **fill that constant in before launch** ([[Release Checklist]]).
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
