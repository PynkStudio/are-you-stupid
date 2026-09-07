---
tags: [ai, quality, safety]
updated: 2026-09-07
---

# Quality Neutrality and Guardrails

How AI addition is kept **quality-neutral** (adding without ever degrading)
and what the machine is allowed to touch. This note is also the home of the
"Do Not Ship Stupid Things" rules the AI must obey.

## Defaults — the app is already complete

- Everything AI-related is **opt-out, never opt-in.** The default install
  profile (`genius` mode, [[Feature Flags]]) is the full optional experience;
  every other posture loses features, not the reverse.
- **There is no quality launchgate.** The app ships when the scripted game
  ships; AI rides along and is toggled when it's ready. "Not ready" is a
  supported end-state ([[Feature Flags]] → rollback), not a bug.
- **App Store retailers get a clean, complete app with no interaction
  required.** No consent modal, no "enable AI" interstitial, no first-run
  hand-tour about the model. If a player never opens Settings, everything
  still works as it does today — with or without the model.
- **AI is never the product.** The trap is the product. There is no "AI
  wallpaper": no splash "Powered by Apple Intelligence", no shrink-wrap badge,
  no settings explainer beyond the honest two lines a player who asks is due
  ([[Error States and Failure Communication]]). The game never mentions itself
  as a model on-screen.

## What the AI may change

Closed set, enforced by the validator and the architecture:

| May change | May NOT change |
|---|---|
| which validated challenge is served ([[AI Challenge Generation]]) | scoring, credits, leveling, streaks, win/loss authority |
| one-line commentary ([[AI Commentary]]) | the game's fail/continue/retry logic and [[Game Engine]] state machine |
| a single spoken trap-hook on a generated challenge | monetization, ads, retention nudges ([[AI as Playing Style]] → "AI in Monetization") |
| (eventually) per-category territory weighting ([[Player Telemetry and Adaptive Difficulty]]) | anything that touches another player's device or the TV's authority ([[Multiplayer AI Director]]) |

"AI never decides" is stated as a hard rule in [[AI as Playing Style]].

## Guardrails (contracts)

1. **Every AI line/instruction is validated** by the deterministic
   [[AI Challenge Validator]] before it is shown — in *both* single-player
   and multiplayer (every receiver re-validates).
2. **Abuse & tolerance.** No slurs, no hate speech, no encouragement of
   self-harm, no references to real people/brands in any AI output. Profanity
   stays inside the game's own [[Humor and Roasts]] pools only. Token-level
   list-backed block + structural checks; a violation is a hard reject
   (`invalid`), never a "regenerate with more sauce".
3. **Punctuation & ASCII.** AI output is ASCII letters/digits and
   `` `',.!?-_ `` only — no emoji, no control characters, no non-latin script
   in v1. This is both the localization floor ([[Localization and Language]])
   and the multiplayer-safe wire form.
4. **Strict length.** Instruction < 8 words; commentary per-`kind` caps
   ([[AI Commentary]]); fail lines / hooks single sentence. Rejected at the
   validator regardless of how clever it is.
5. **No AI-only categories.** Every category that exists has a scripted
   fallback ([[Dynamic AI Director]]). There is no content that *only* AI can
   produce in a shipped build.
6. **No meta-about-the-AI.** No output that references the model, generation,
   or Apple Intelligence. A line that says "the AI made this" is rejected.
7. **Refused prompts are not retried as-is.** A `guardrailViolation` /
   refusal ends that unit ([[Foundation Models Integration]] → error mapping);
   regenerating the same request is a bug.
8. **Never degrade the floor.** If any part of the AI path is uncertain, the
   player sees the scripted path — never a blank, a pause, or a half-cooked
   challenge ([[Pre-generation Cache]] invariants).

## Mitigation & rollback

Because every AI failure mode ends in "the unmodified scripted game", the
rollback ladder is trivial and instant:

| Rung | What flips | Player impact |
|---|---|---|
| 1. Unit failover | a single unit fails/`failureExit` | that round is scripted; AI keeps trying next unit |
| 2. Per-feature flag | `aiChallengeGenerationEnabled` … off | that use-case is scripted session-wide |
| 3. Mode | `ayu.dynamicAI.mode` → `classic` | entire experience is pure scripted |
| 4. Master | `dynamicAIEnabled = false` | no AI code runs; identical to pre-AI build |

`async` generation already killed on flag/mode flip per unit
([[Pre-generation Cache]] → cancellation). The same team owns both paths, so
"who is responsible" is one answer: the game team, via the same repo.

## Related

- [[AI Challenge Validator]] — where these contracts are enforced
- [[Feature Flags]] — the tri-state ladder this sits on
- [[AI as Playing Style]] — scoring/leveling/monetization hard rules
- [[Error States and Failure Communication]] — honest Settings copy
- [[Testing and Evaluation]] — guardrail tests as a suite