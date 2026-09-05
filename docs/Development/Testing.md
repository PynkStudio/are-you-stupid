---
tags: [development, testing]
updated: 2026-09-06
---

# Testing

```bash
flutter test          # everything
flutter analyze       # must be clean, zero issues
```

## Known issue: intermittent overflow in `app_flow_test.dart`

**"the run is recorded in the stats screen" fails roughly 1 in 5–8 runs**,
even in isolation (`flutter test test/app_flow_test.dart` alone, same test
data every time). The failure is a real Flutter layout error, not a flaky
assertion:

```
A RenderFlex overflowed by 24 pixels on the bottom.
```

in [`StatsScreen`](../../lib/ui/screens/stats_screen.dart)'s outer `Column`
(title + score card + three `_Row`s + `Spacer` + `BACK` button, all
non-scrolling). The test data is identical on every run (`bestLevel: 1`,
fresh `SharedPreferences.setMockInitialValues({})`), so the size that
overflows isn't a content-size problem — something about text/font metrics or
frame timing differs between runs. Not yet root-caused. Re-running usually
passes. **Not introduced by, or fixed as part of, the 2026-09-06 publishability
audit** ([[Decision Log]]) — flag it separately before relying on `flutter
test` as a hard release gate.

## The five suites

### `test/challenge_templates_test.dart` — the contract
Runs **every** registered template across 12 seeds × 3 level bands and asserts:

- registry has ≥ 30 templates with unique ids
- starters are available at levels 1–3
- round length between 0.6 s and 8 s
- instruction is **under 8 words** (the design rule, enforced)
- target ids unique, scale > 0, opacity in 0.2–1.0
- the round always resolves if the player does nothing

A new template is covered by this the moment it is registered.

### `test/challenge_behaviour_test.dart` — the rules
Per-challenge: the winning input, the losing input, the trap, the exact fail
line. Uses `FakeHost` + `advance()` from `test/support/fake_host.dart`, so no
widgets and no clock.

### `test/game_engine_test.dart` — the loop
Phases and timings, level progression, roasts, timeout, input ignored outside
`playing`, continue-once-per-run, event emission, and the generator rules
(starter gating, no back-to-back repeats, `minLevel` respected).

### `test/app_flow_test.dart` — the real widget tree
Menu → PLAY → LEVEL 1 → timeout → Game Over → TRY AGAIN, stats recording, and
the settings toggles. Note: `pumpAndSettle()` never settles on the game screen
(it animates every frame by design) — advance with fixed `pump(step)` loops.
See the known intermittent overflow above.

### `test/ad_manager_test.dart` — the ad policy
`AdManager` against a fake `AdProvider` that never has a fill: asserts the
rewarded-continue button is never offered when `isReady` is false, i.e. the
"no dead-end ad buttons" rule actually holds when offline. See [[Monetization
and Ads]].

## Writing tests for a new challenge

```dart
final c = buildMyChallenge(params(level: 10));
final host = FakeHost();
c.onStart(host);
advance(c, host, to: const Duration(milliseconds: 800)); // let the trap arm
c.onTap(tapOn('c2'), host);
expect(host.failed, isTrue);
expect(host.reason, 'THAT ONE WAS HONEST.');
```

## Manual pass before shipping

See [[Release Checklist]].
