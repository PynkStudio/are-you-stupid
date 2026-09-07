---
tags: [ai, architecture, performance]
updated: 2026-09-07
---

# Pre-generation Cache

The machinery that makes "AI never blocks gameplay" a **provable** property
instead of a hope. Lives in `lib/ai/` (pure Dart); only
[[Foundation Models Integration]] touches the model.

## Invariants (contracts, not intentions)

1. **A served challenge is always valid.** Nothing enters the game from the
   cure-but-never-served boundary without passing
   [[AI Challenge Validator]].
2. **A cached challenge is always validated.** The cache only ever holds
   `valid` outcomes. A `failureExit` unit leaves the cache untouched.
3. **No regeneration in the input path.** Re-generation (one attempt) happens
   *only* inside the prefetch loop. The round-start read never asks the model
   for anything.
4. **Underflow ⇒ scripted, never empty, never late.** If the cache has no
   candidate when the engine asks, `FallbackChallengeProvider` returns a
   scripted challenge immediately. There is no code path where the player
   waits on the model.

## Anatomy

```
levelStarted / correct / wrong ──► Director.prefetch()
      │  (async; never awaited by the engine)
      ▼
PrefetchLoop (single in-flight generation — GlobalSerial)
   ├─ unitId = UUID()            registry so cancelUnit() can discard stale work
   ├─ read ctx { level, locale, allowTricks, timeLimitSla, profile }
   ├─ request(base, "requestChallenge")  or  request(kind, "requestCommentary")
   ├─ validate()  case valid → enqueue   one regeneration → still invalid → failureExit
   └─ on any GenerationError / availability loss → mark unit failed, don't enqueue

engine asks: FallbackChallengeProvider.take() → cache.popNext() ?? scripted
```

- **Buffer shape:** a small ring of futures: `challenge` ring (size 2) and
  `commentaryByKind` rings (size 1 per kind). Sized to cover a wrong-flash or
  a round transition — never unbounded.
- **Every read is `take`:** popping a cached challenge *deletes* it (no
  serving a stale reroll), so the loop refills topically on the next event.
- **Cancellation:** when a mode/flip/flag changes, `cancelUnit(unitId)` marks
  in-flight units dead. The Swift single-`await` generation either completes
  (then validation discards it) or is simply ignored — see
  [[Foundation Models Integration]] → "cancelUnit".
- **Staleness:** the cache is keyed by `{ locale, level-band, allowTricks }`
  and invalidated on any of those changing — a cached round for old language
  or a pre-trick level is never served after the flip.

## Latency / SLA

- The prefetch for the *next* round is triggered at the moment the *current*
  round is judged (`correct`/`wrong`/`timeout`) — that gives the model up to a
  full round to produce a candidate. `timeLimitSla` passed to Swift is this
  remaining window, and Swift's own work otherwise runs on a background queue
  ([[Performance and Resource Budgets]]).
- If `timeLimitSla` is already exhausted (ultra-fast round), the loop **skips
  this round entirely** and refills during the next one — it never "hurries"
  the model, because there is no hurry: underflow simply means scripted.
- Commentary prefetch happens per kind well before the moment it's shown
  (e.g. `wrong` commentary is requested at `levelStarted` of the round that
  might fail).

## Impact & guards

- **Thermal/power:** prefetch runs on a background queue, at most one in
  flight, skips when availability is off or when the app is backgrounded. See
  [[Performance and Resource Budgets]] for the budget table and the kill
  switches.
- **Observed locally (no analytics out):** per-session counters —
  `challengesGenerated`, `challengesValidated`, `challengesServed` (hit/miss),
  `regenerations`, `failuresByReason`, `averageGenerationMs` — feed the
  internal "AI quality" dashboard described in [[Privacy and Offline]], and
  nothing leaves the device ([[Feature Flags]] → observability flag).

## Related

- [[Dynamic AI Director]] — the three-part split-brain this belongs to
- [[AI Challenge Validator]] — what "validated" means, exactly
- [[Performance and Resource Budgets]] — generation and latency budgets
- [[AI Commentary]] — the same machinery prefetching lines
- [[Testing and Evaluation]] — cache-unit tests (starvation, latency,
  cancellation)