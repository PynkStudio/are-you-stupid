---
tags: [meta, rules, mandatory]
updated: 2026-09-07
---

# Documentation Rules

> **These rules are binding for every AI agent and every human working on this
> repository. They are not a suggestion.**

This vault is not a summary written after the fact. It is **part of the
deliverable**. A change that lands without its documentation update is an
incomplete change.

## The rule

**Every commit that changes behaviour, structure or product decisions MUST
update the affected note(s) in `docs/` in the same commit.**

No "I'll document it later". No separate docs PR.

## What to update, when

| You changed… | You must update |
|---|---|
| Added / removed / renamed a challenge | [[Challenge Catalog]] (+ [[Adding a Challenge]] if the procedure changed) |
| `minLevel`, `weight`, speed, timing floors | [[Difficulty Curve]] and the row in [[Challenge Catalog]] |
| Engine phases, timings, events | [[Game Engine]] |
| `Challenge` / `ChallengeView` / `TapInfo` API | [[Challenge System]] and [[Adding a Challenge]] |
| Layouts, theme, renderer | [[Rendering Pipeline]] |
| A service, or added one | [[Services]] |
| Stored keys, persistence | [[State and Persistence]] |
| Ad placements or policy | [[Monetization and Ads]] |
| Share text, viral prompts | [[Virality and Sharing]] |
| Roast pools, fail lines, tone | [[Humor and Roasts]] |
| Build, run, tooling, dependencies | [[Getting Started]] |
| Tests or test strategy | [[Testing]] |
| Scope: shipped / planned / rejected | [[Roadmap]] |
| A non-obvious technical or design decision | [[Decision Log]] — append, never rewrite |
| The multiplayer wire contract / messages / version | [[Multiplayer Protocol]] |
| Host/room/game authority, timing, reconnect | [[Multiplayer Architecture]] |
| Host UI or host engine (tvOS **and** macOS board host, `tvos/` / host target) | [[Multiplayer Host (tvOS)]] |
| Mobile controller UI or client engine (`lib/multiplayer/`) | [[Multiplayer Client (Mobile)]] |
| Modes, rounds, scoring, elimination, TV humor | [[Multiplayer Gameplay]] |
| Multiplayer challenge families or seeding | [[Multiplayer Challenges]] |
| Multiplayer ads, sharing, join UX, scope | [[Multiplayer Product]] |
| Multiplayer build order or test/sim harness | [[Multiplayer Development]] |
| AI: the director, its pipeline, the bridge contract, or phase plan | [[Dynamic AI Director]] (+ [[Feature Flags]] if flags/modes changed; [[Foundation Models Integration]] if the `ays/apple_intelligence` contract changed; [[Development Plan]] when a Phase lands) |
| AI: proposal schema, mechanics, any generated-challenge shape | [[AI Challenge Generation]] (+ [[AI Challenge Validator]] if validation rules changed) |
| AI: validator rules or verdicts | [[AI Challenge Validator]] |
| AI: telemetry/profile/adaptive territory | [[Player Telemetry and Adaptive Difficulty]] |
| AI: commentary kinds or length gates | [[AI Commentary]] |
| AI: caching/SLA/cancellation | [[Pre-generation Cache]] (+ [[Performance and Resource Budgets]]) |
| AI: profiles, tool set, prompts | [[Dynamic Profiles and Tool Calling]] |
| AI: multiplayer wire kinds / Director Host election | [[Multiplayer AI Director]] (+ [[Multiplayer Protocol]]) |
| AI: privacy, persistence, observability, offline posture | [[Privacy and Offline]] (+ [[State and Persistence]]) |
| AI: localization/locale gating | [[Localization and Language]] |
| AI: quality/guardrail/rollback posture | [[Quality Neutrality and Guardrails]] |
| AI: test strategy for the AI suites | [[Testing and Evaluation]] (+ [[Testing]]) |

### Spec documents

The `docs/AI/` set is, until implementation, the *only* authorized
"aspirational" documentation in the vault: they are the spec for a
deliberately docs-first phase ([[Development Plan]] Phase 0) and each one
carries an explicit "spec, not shipped code" posture. **Every other rule
applies to them the moment their subject ships** — and what ships must be
described truthfully then (addendum + `updated:` bump, same commit). Until a
`docs/AI/` subject ships, no other note may cite it as if it were landed;
[[Home]] marks the whole area as spec.

## How to write here

1. **Obsidian vault.** Link notes with wiki links (double square brackets) using the exact note title.
   Never link a note that does not exist.
2. **Front matter** on every note: `tags` and `updated: YYYY-MM-DD`. Bump
   `updated` when you touch it.
3. **Describe the code that exists**, not the code you plan to write. No
   aspirational documentation.
4. **State the why.** The *what* is readable in the source; the reason a
   flash lasts 240 ms is not.
5. **Delete what stops being true.** A stale note is worse than no note.
6. Keep it short. If a note grows past ~150 lines, split it and link.

## Before you say you are done

```bash
flutter analyze     # zero issues
flutter test        # all green
```
- [ ] docs updated in the same change
- [ ] `updated:` dates bumped
- [ ] no dangling wiki links
- [ ] [[Home]] still lists every note

## Why this is enforced

This project is built and maintained mostly by AI agents in short sessions with
no shared memory. This vault **is** the memory. Let it rot and the next agent
re-derives the design from scratch, gets it wrong, and the game stops being
funny.
