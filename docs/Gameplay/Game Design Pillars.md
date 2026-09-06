---
tags: [design, pillars]
updated: 2026-09-06
---

# Game Design Pillars

## The joke

The player must always think *"this is fucking easy"* — and then fail on something
stupid. The game makes them question whether **they** are the problem.

The target reaction after losing is **not** "this game sucks", it is
**"I know what I did wrong. Let me try again."**

Everything in this repo is judged against that sentence.

## Hard rules

1. **Fair, not random.** Every failure must be explainable in one sentence by the
   player. If a challenge cannot be understood *after* losing, it is a bad
   challenge. See [[Challenge Catalog]].
2. **Under 8 words** per instruction. Enforced by a test in [[Testing]].
3. **Zero downtime.** Correct answer → 240 ms green flash → next challenge.
   Mistake → 2.85 s red flash with the roast (long enough to actually read
   it — tap it to skip straight to Game Over if you already know why you
   lost) → Game Over. No loading, no route changes.
4. **One hand, one thumb.** Everything is a tap or a hold. No swipes, no
   multi-touch, no precision dragging.
5. **Offline first.** No account, no network, no backend. The one deliberate
   exception is ads: they need a round trip by nature, but the game itself
   must stay fully playable with zero connectivity, and no ad-gated action
   (continue, extra life, etc.) may ever be offered when no ad is actually
   available. See [[State and Persistence]] and [[Monetization and Ads]].
6. **No external assets.** Every visual is generated from native widgets, shapes,
   gradients and text. Audio uses platform system sounds. This keeps the binary
   tiny and the load instant.
7. **9:16 first.** The screen must read well in a vertical screen recording —
   large type, huge targets, strong color states. See [[Virality and Sharing]].

## Session shape

- One run = 20 s to 2 min.
- A challenge = 1–5 s.
- Score = the level you reached. Nothing else is a score.
- Restart = one tap, under a second (the Game Over screen is a layer on the game
  screen, not a route).

## Where difficulty comes from

Not reflexes alone. In order of importance:
misleading wording → changing rules → ambiguous instructions → fake buttons →
visual distraction → memory → timing → raw speed.

See [[Difficulty Curve]].
