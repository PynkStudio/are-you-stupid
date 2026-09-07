---
tags: [ai, localization, language]
updated: 2026-09-07
---

# Localization and Language

The AI feature's relationship with the game's supported languages
([[Localization]]). The rule is deliberately boring:

> **v1 model output is English-only.** Every other locale plays the AI modes
> with the static, fully-localized scripted bank — *never* machine-translated
> or English-locale content.

## Why

- The model's `supportedLanguages` and output quality are **English-first**;
  shipping non-English AI output in v1 would ship the riskiest part of a
  quality-neutral feature ([[Quality Neutrality and Guardrails]] → no
  degradation) in exactly the places we cannot test ([[Testing and Evaluation]] → no device-language playtesting on a team's simulator).
- All system prompts, `GenerationSchema` descriptions, tool argument docs,
  and guardrail lists are **compiled-in English**. The API surface does not
  translate: the prompt language and the game's UI language are separate
  concerns.
- A player's language **never flows into generation** in v1. `locale` is the
  *enabled/disabled* signal, not a prompt input.

## What each locale sees

| Locale | AI challenge generation | AI commentary | Scripted tuning |
|---|---|---|---|
| `en` | generated (validated, [[AI Challenge Generation]]) | generated per kind ([[AI Commentary]]) | unchanged |
| any supported non-`en` locale ([[Localization]]) | scripted (the whole AI unit marks `localeNotSupported` → scripted, [[Foundation Models Integration]] error mapping) | static bank (fully localized [[Humor and Roasts]]) | unchanged |

So for a non-English player the game is exactly today's game — which is the
safest possible posture for a feature that localizes later.

## The localizable seams that *are* the feature

A handful of strings are player-facing and must be in the full locale set:

- **Settings AI section copy** (modes, availability states, one-line
  explanations — [[Error States and Failure Communication]])
- **Countdown hint in the couch phone UI** for multiplayer AI rounds
  ([[Multiplayer AI Director]])
- **The generic "scripted fallback" explanation line** used wherever the AI
  path silently degrades ([[Error States and Failure Communication]])

All of these are ordinary `App` localization entries, not model output; the
model never writes them.

## Future

When a locale graduates, it enters the same contract as English: model output
still validated by the same validator rules (ASCII-whitelisted, per-kind
length, tone), with the *only* difference being that non-English output must
round-trip through OCR-sanity in playtests ([[Testing and Evaluation]]). The
guardrail against mixed-language output (an English word sneaking into a
French line) is the validator's per-kind word list check.

## Related

- [[Localization]] — the game's language matrix
- [[AI Challenge Generation]] / [[AI Commentary]] — English-only generation rules
- [[AI Challenge Validator]] — the ASCII + tone checks that gate any locale
- [[Foundation Models Integration]] — `UnsupportedLanguageOrLocale` error
- [[Feature Flags]] — the mode/full-feature flow per device