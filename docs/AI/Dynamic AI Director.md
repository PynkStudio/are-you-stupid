---
tags: [ai, architecture, overview]
updated: 2026-09-07
---

# Dynamic AI Director

An **Apple Intelligence–powered Dynamic Game Director**: the on-device
Foundation Model turns the player into a *game*. It watches every tap, adapts
challenge difficulty in real time, roasts the player between rounds, and (in
party mode) becomes a full game director for the room — while the scripted
engine stays the floor underneath everything.

> **Status: spec, not shipped code.** This is the Phase 0 design write-up,
> mirroring how the multiplayer feature landed ([[Decision Log]] →
> "spec-first documentation pass"). As each phase lands, these notes get bumped
> to describe the code that exists. Home.md marks the feature's build state.

## The one sentence

> The system model invents perfect "ARE YOU STUPID?" challenges tuned to this
> exact player, thinks up a fresh roast for every failure, and runs party
> rounds like a host — and if it is ever wrong, slow, or absent, the player
> gets the exact same game they have today, with zero waiting.

## Goals

- **A game that knows you.** The Director reads gameplay telemetry
  ([[Player Telemetry and Adaptive Difficulty]]) and picks/adjusts what you
  play. Not a new difficulty slider — difficulty becomes invisible.
- **Fresh humor.** AI-generated commentary and roasts on top of the existing
  static pools ([[Humor and Roasts]]), first in English only, AI-localized
  later ([[Localization and Language]]).
- **Modern *unplayable-by-design* moments.** New joke mechanics that are too
  local to the player to hand-author (e.g. a challenge that quotes the
  player's *own* failure patterns back at them).
- **A real party host.** In multiplayer, one capable iPhone/iPad becomes the
  "AI Director Host", inventing rounds and commentary for the room
  ([[Multiplayer AI Director]]).
- **Ship it as a product feature** — an opt-in SKU/experience
  ([[Feature Flags]]), marketed ("AI-enhanced"), with a graceful
  auto-disable on any failure condition.

## Non-goals

- **No replacing the scripted engine.** The 39 templates stay the spine. AI is
  additive, optional, and never the only path.
- **No server-side AI, no cloud, no accounts.** Everything runs on the device
  through `FoundationModels` (iOS 26+). Offline pillar intact
  ([[Privacy and Offline]]).
- **No AI in scoring, ranking, monetization, or matchmaking.** AI never decides
  a score, never prices anything, and never settles a multiplayer winner on
  its own ([[AI as Playing Style]] → "AI in Scoring").
- **No training on player data.** Foundation Models handles no fine-tuning;
  telemetry is local-only and bounded ([[Privacy and Offline]]).
- **No replacing the apple-tv host authority.** The Apple TV never runs the
  model ([[Multiplayer AI Director]]).
- **No pixel-level custom rendering.** Generated challenges map onto existing
  layouts via a controlled mechanic vocabulary ([[AI Challenge Generation]]).

## Do not ship stupid things

The [[Game Design Pillars]] rules that apply to the human author apply to the
generated content too, and the deterministic validator *enforces* them
([[AI Challenge Validator]]). Generated content must always satisfy:

1. **Instructions are under 8 words** and uppercase on screen. Violations are
   rejected and one regeneration is attempted.
2. **Every failure is explainable in one line.** Every generated challenge
   ships its own fail line; every AI commentary line is a single sentence.
3. **A generated challenge targets at least 2 of the 8 senses**
   (`color` + `size`, `instruction` + `timing`, `words` + `motion`, ...),
   matching how hand-written challenges force the brain through two channels.
4. **No punishment for being observant; confusion is the prize.** Generated
   content must hide truth *inside* logic, never require reading the model's
   mind. An instruction that is impossible to follow is a bug, not a joke.
5. **Wrong answers must be tempting** — generated decoys must be
   *inverted/mirror* versions of the correct answer (wrong color, other button,
   reverse wording), never "random noise" the player cannot reconstruct
   afterwards as a *plausible* mistake.
6. **No inaccessible, flashing-abusive, or timing-unfair content.** Validator
   floors apply to `timeLimit`, target `scale`, `opacity`, and target count,
   whatever the model suggests ([[AI Challenge Validator]]).

## Design decisions that are final

- **Scripted = ground truth. Fallback = scripted.** Any invalid, refused,
  slow, or unavailable model result resolves silently to the scripted path.
  The player never sees an AI error message ([[Error States and Failure Communication]]).
- **AI is never authoritative; the Dart validator is.** The wire/bridge format
  is only a *proposal* until it passes `validate()`.
- **Gameplay never blocks on AI.** The Director feeds the engine from a
  pre-generation cache; the engine treats the Director as optional
  ([[Pre-generation Cache]]).
- **No streaming the model to multiplayer devices.** Only compact structured
  results (`challenge`, `commentary`, `roundId`) travel over the wire
  ([[Multiplayer AI Director]]).

## The challenge pipeline

```
player taps / fails / times out
        │  every event, cheap telemetry → lib/core/difficulty.dart knows nothing about AI
        ▼
GameEngine (unchanged spine)
        │  requests next level
        ▼
ChallengeGenerator.next(level)  ── refactored to consult a ChallengeProvider ──►  Director
        │                                                                              │
        ├─ ScriptedChallengeProvider (always present, the floor)                       │
        └─ AIChallengeProvider      (in async loop with the model, fills the cache)    │
                every candidate → ChallengeValidator.validate()
                pass  → enqueue  ([[Pre-generation Cache]])
                fail  → one regeneration, then scripted                          read cache → engine
```

Who provides the next challenge ([[AI Challenge Generation]]) is decided by
[[Feature Flags]] and the AI Experience Modes ladder defined there, not by the
model — see "Real-time AI Director + caching" below and [[Pre-generation Cache]].

## Real-time AI Director + caching

The Director is a **three-part split-brain** by construction:

1. **The Dart Director** (`lib/ai/`) — owns availability, modes, feature
   flags, the cache queue, the validator, and the fallback switch. It can
   only call the platform bridge.
2. **The Swift Foundation Models service** (`ios/Runner`) — the *only* code
   that may touch `FoundationModels`. It exposes a `respond(schema:)`
   surface ([[Foundation Models Integration]]) and returns validated-by-schema
   JSON proposals.
3. **The scripted engine** — the floor and, when AI is unavailable or off,
   the whole experience.

The Director runs a **pre-generation loop**: on `levelStarted`, ahead of the
*next* level (plus commentary ahead of the *next* failure), it asks the model
for candidates with a latency SLA ([[Performance and Resource Budgets]]). When
the player reaches the next round, the cached candidate is immediately
available — the model never sits in the input path.

- Cache underflow (SLA missed / generation refused / generation failed /
  availability lost) ⇒ the engine consumes from the scripted path. No empty
  round, ever.
- Invariants that are contractually true and tested: **a cached challenge is
  always validated; a served challenge is always valid** — no challenge is
  served to the player from the cache unless it passed the validator, and no
  challenge is ever regenerated *in the input path* (regeneration happens only
  in the prefetch loop) — see [[Pre-generation Cache]].

## Related

- [[Foundation Models Integration]] — the on-device model surface
- [[AI Challenge Generation]] / [[AI Challenge Validator]]
- [[Player Telemetry and Adaptive Difficulty]]
- [[AI Commentary]]
- [[Pre-generation Cache]]
- [[Multiplayer AI Director]]
- [[Feature Flags]]
- [[Quality Neutrality and Guardrails]]
- [[Privacy and Offline]]
- [[Performance and Resource Budgets]]
- [[Localization and Language]]
- [[Error States and Failure Communication]]
- [[AI as Playing Style]]
- [[Testing and Evaluation]]
- [[Development Plan]]