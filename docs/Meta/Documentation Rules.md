---
tags: [meta, rules, mandatory]
updated: 2026-09-05
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
