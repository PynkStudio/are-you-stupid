---
tags: [gameplay, tone, copy]
updated: 2026-10-03
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

The future [[Multiplayer Presenter]] uses the same gate for spoken titles and
callbacks. Savage narration is meant to get genuinely close to the tone limit:
it can repeatedly weaponize a player's real mistakes, ranking and collapsed
reputation. The limit itself is absolute — never protected traits, body or
appearance, sexuality, health/disability, family/trauma, threats, real-world
allegations or attacks on human worth. It roasts the night's evidence, not the
person's life.

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

## Useful system jokes

Setup failures may use the same dry voice only when the joke also names the
fix. Multiplayer's known off-Wi-Fi state says `NO WI-FI. THE TV ISN'T
TELEPATHIC. JOIN ITS NETWORK.` (transcreated in every locale) instead of
pretending that room discovery is still useful. Unknown connectivity and an
actual empty Wi-Fi LAN keep neutral copy: never roast the player for a cause
the app cannot prove.
