---
tags: [gameplay, tone, copy]
updated: 2026-09-06
---

# Humor and Roasts

`lib/data/roasts.dart` picks; the lines themselves live in
`lib/i18n/strings_*.dart` under `roast.*`, one pool per language — see
[[Localization]]. A translation must **transcreate** the joke, not translate
it literally: the goal is "short, playful, teases the mistake" in that
language, not a word-for-word rendering of the English slang.

## Tone

Playful, never hostile. The game teases *the mistake*, not the person.

Three pools:

- **neutral** — `NOPE.` `WRONG.` `NOT QUITE.` `OOF.` `AGAIN?`
- **spicy** — `YOU HAD ONE JOB.` `BRUH.` `MY GRANDMA GOT FURTHER.` `JUST READ.` `💀`
- **late** — reserved for timeouts

`Roasts.forMistake()` picks neutral ~55 % of the time. With **SAVAGE MODE** off
in Settings, only the neutral pool is used (`GameEngine.spicyRoasts`).

## Challenge-specific lines beat random ones

When a challenge passes a `reason`, that line is shown instead of a random
roast. These are the *useful* ones, because they teach:

| Situation | Line |
|---|---|
| tapped before green | `IMPATIENT.` |
| one tap too many | `TOO MANY.` |
| tapped the word instead of the color | `THAT ONE ONLY SAID IT.` |
| followed an ignored instruction | `YOU WERE TOLD TO IGNORE IT.` |
| released a hold | `YOU LET GO.` |
| timing error | `+0.62s OFF.` |

**Rule: a new challenge must ship with its own fail line.** A generic roast on a
tricky challenge feels unfair; a specific one feels like a joke the player is in
on. See [[Game Design Pillars]].

## Praise is understated

Success shows `YES` plus an occasional dry note (`NICE RESTRAINT.`,
`WOW. YOU DID NOTHING.`, `PARADOX SURVIVED.`). Never enthusiastic. The game is
not impressed by you.
