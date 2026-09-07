---
tags: [ai, performance, budgets]
updated: 2026-09-07
---

# Performance and Resource Budgets

The numbers that make "never blocks gameplay" and "never a battery/thermal
pain" *measurable*. All budgets are **soft by one direction**: tearing through
them degrades the *AI* path (→ scripted), never the player's frame.

## Latency budget table

| Unit | Budget | Meaning / consequence |
|---|---|---|
| `challenge` SLA | ≤ **500 ms** | a generated candidate must be ready before the round that needs it; enforced by *when* the prefetch starts ([[Pre-generation Cache]]), not by hard-capping the model. Underflow → scripted. |
| `commentary` SLA | ≤ **150 ms** | a line must exist before the flash moments that show it; underflow → static bank line. |
| `cacheWait` limit | 0 | there is no "wait for cache". The engine's request path never awaits generation. |
| max concurrent generation sessions | **1** (global) | one model session total — single-threaded interaction with the model. The perf-annotated `session.session_mutex`/perf model ensures concurrent requests are tests, never runtime behavior. |
| preloading concurrency limit | 1 | the prefetch loop issues at most one in-flight request; the next `prefetch` event is queued. |
| budgets apply | only when `availability == available` && flag on | when availability is off, no generation work starts at all. |

## Thermal & power

- Prefetch runs on a **background queue** and **skips** when the app is
  backgrounded (a round is never "waiting" anyway — pauses are off-device
  anyway).
- The single-in-flight and 1-at-a-time-queue rules cap sustained GPU/ANE
  load: worst case is one short generation between rounds, matching the
  power profile the scripted game already has (continuous taps, no sustained
  background work).
- No new continuous background work is introduced — the prefetch loop is
  event-driven (fires on `levelStarted`/`correct`/`wrong`), *not* a timer.

## Contexts

- `promptContextSize` is fixed at the model's `contextSize` (4096, compact
  fix — [[Foundation Models Integration]]). Generation is capped well under
  that by construction: structured proposals with `maximumResponseTokens`
  caps per profile ([[Dynamic Profiles and Tool Calling]]); prompts never
  carry the raw history (the tool facade is the 10-round cap, [[Privacy and Offline]]).
- Generation is tapped **per units** (challenge/commentary/round) with one
  profile per call — never one giant all-game conversation.

## Counterpart: latency is what players feel

The budgets exist so the *hardware* question ("can it run the model?") stays
an availability matter, not a frame-time matter. The measurable player-facing
invariant is: **no input path of the game ever waits on the model.** That
invariant is unit-tested ([[Testing and Evaluation]] → cache starvation).

## Related

- [[Pre-generation Cache]] — where every SLA turns into underflow/fallback
- [[Foundation Models Integration]] — severity & error mapping on
  generation errors
- [[Feature Flags]] — when budgets don't even start
- [[Testing and Evaluation]] — latency-margin golden tests