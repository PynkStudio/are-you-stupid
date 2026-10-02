---
tags: [ai, localization, language]
updated: 2026-10-02
---

# Localization and Language

The AI feature's relationship with the game's supported languages
([[Localization]]).

> **The AI speaks the player's language — challenges and commentary, in all
> six locales** (en/it/fr/es/pt/de). Model text is written directly in that
> language, *never* machine-translated English. Multiplayer is the one
> exception: the Director still writes English for the whole room.

**History.** v1 was English-only for every AI unit. On 2026-10-02 the owner
opened it up — first commentary, then challenge generation — because a
non-English player saw no AI at all ([[Decision Log]]). The on-device model
supports all six languages; the limit was ours, not Apple Intelligence's.

## What each locale sees

| Locale | AI challenge generation | AI commentary |
|---|---|---|
| `en` | generated, instruction **under 8 words**, strict ASCII | generated, ASCII |
| it/fr/es/pt/de | generated **in that language**, instruction **up to 10 words**, Latin script, **+1 s** (+2 s past 7 words) | generated in that language, Latin script |
| multiplayer (any) | English (the Director asks in `en` for everyone) | English, ASCII on the wire |

Anything the model gets wrong still lands on the fully-localized scripted
bank / static roasts — the fallback ladder is unchanged.

## How it works

- **Prompts stay English**, compiled in. They name the *output* language
  (`aysLanguageName`, Swift) — instruction and element labels for
  challenges, the line for commentary
  ([[Dynamic Profiles and Tool Calling]]).
- **Fail lines are hand-written, not generated:** `kCanonicalFailLines` in
  `ChallengeGenerationProfile.swift` has one line per mechanic per locale,
  so the one-line failure explanation the pillars require
  ([[Game Design Pillars]]) stays predictable even when the model's text is
  off.
- **Validation per locale** ([[AI Challenge Validator]]): player-facing text
  (instruction, labels, fail line, commentary) uses `kLatinAllowlist`
  outside English, `kAsciiAllowlist` in English; ids and enum names are ASCII
  everywhere. Word cap `instructionMaxWords` (7 en / 10 others), uppercase
  check is Unicode-aware, the imperative-verb check uses the locale's verbs
  (`AiAction.imperativeVerbsFor`, matching the scripted bank's `TOCCA`,
  `TOUCHE`, `TOCA`, `TOQUE`, `TIPPE`…), and the tone lists carry a few
  localized forbidden/meta-AI tokens.
- **Time compensation:** `localeTimeBonusMs` adds +1 s to a non-English AI
  challenge, +2 s when its instruction is longer than English's cap. Added
  when the challenge is built (`buildFromProposal`), on top of the model's
  `timeLimitMs`; the time floor still checks the model's own number.

## Why wordier languages get more words and more time

The owner's call: if a language can't say it in under 8 words, that's the
language's problem, not the player's. The same sentence is longer in
German or French than in English; forcing 7 words there would mostly
reject good proposals (→ scripted) or produce telegraphic text. The cap is
10, not unlimited, and the extra second pays for the extra reading. English
keeps the original law.

## Risks still open

Quality in each language is **unverified on real hardware** (none here):
label ambiguity, wordplay that doesn't translate, imperative-verb lists
that miss a valid phrasing (→ rejection, scripted fallback, never a broken
round). See [[Testing and Evaluation]].

## Related

- [[Localization]] — the game's language matrix
- [[AI Challenge Generation]] / [[AI Commentary]]
- [[AI Challenge Validator]] — the per-locale checks
- [[Foundation Models Integration]] — `UnsupportedLanguageOrLocale` error
- [[Feature Flags]] — the mode/full-feature flow per device
