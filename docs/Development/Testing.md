---
tags: [development, testing]
updated: 2026-09-06
---

# Testing

```bash
flutter test          # everything
flutter analyze       # must be clean, zero issues
```

## Fixed: intermittent overflow in `app_flow_test.dart`

Several tests that reach Game Over used to fail intermittently (roughly 1 in
5–8 runs, "same test data every time") with:

```
A RenderFlex overflowed by 24 pixels on the bottom.
```

Root cause: [`GameOverView`](../../lib/ui/screens/game_over_view.dart)'s
outer `Column` is deliberately non-scrolling, and two of its lines —
the roast and the viral prompt — are picked at random from pools of very
different lengths (`roast.spicy.10` is 8 words; most neutral lines are one).
An unlucky long pick wrapped to a second line at 40px, and the layout had no
slack left for it. "Same test data" was true (`bestLevel: 1`) but the
random roast/viral text wasn't — that's what actually varied between runs.
**Fix:** wrapped both in `FittedBox(fit: BoxFit.scaleDown)`, the same idiom
already used for the level number two lines below (see [[Rendering
Pipeline]]'s "Labels use `FittedBox`" rule) — a long line shrinks to fit
instead of wrapping and blowing the column. See [[Decision Log]].

## The seven suites

### `test/challenge_determinism_test.dart` — the multiplayer seed contract
For every registered template across 4 seeds × 3 level bands: same
`{ challengeId, seed, level }` → deep-identical `ChallengeView` (every
render-relevant field compared), stable duration/id, unknown ids resolve to
`null` from `templateById`, and unknown ids throw from `buildFromSeed`. This
is what guarantees host and every phone rebuild the same challenge from a
`ROUND_START` tuple — see [[Multiplayer Challenges]] and [[Decision Log]].

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
See the overflow fix above.

Also asserts the `TimerBar` is actually visible at level 1 — including that
its colored fill renders at its real 8 px height, not the zero-height layout
bug fixed in [[Difficulty Curve]] — and that tapping the wrong flash calls
`GameEngine.skipWrongFlash()` and reaches Game Over well before
`wrongFlash` would have elapsed on its own.

Also covers the Settings screen's external links ("ABOUT THE GAME", "PRIVACY
POLICY", the "Made by PynkStudio" credit — see [[Services]]): a
`_FakeUrlLauncher` replaces `UrlLauncherPlatform.instance` for the test so
tapping the rows records the URL instead of opening a real browser. Two
variants cover the locale-dependent "about" link: English gets the `/en`
case-study page, Italian gets the Italian one.

### `test/ad_manager_test.dart` — the ad policy
`AdManager` against a fake `AdProvider` that never has a fill: asserts the
rewarded-continue button is never offered when `isReady` is false, i.e. the
"no dead-end ad buttons" rule actually holds when offline. Also covers the
"remove ads" purchase: once `SettingsManager.noAdsPurchased` is set, the
rewarded continue is granted for free (offline included) and the interstitial
never fires, even with the fill/counter conditions that would otherwise show
one. See [[Monetization and Ads]].

### `test/localization_test.dart` — the six languages stay in sync
Asserts every locale in `lib/i18n/strings_*.dart` defines the exact same key
set as English (a stray/missing key otherwise fails silently into the English
fallback — see [[Localization]]), that no key is left empty, that
`spell_count`'s per-language letter/digit maps are complete, and that
`word.opposite.*` pairs are well-formed. Also re-runs the **under 8 words**
instruction rule across every template in every language (not just English —
this is what caught a French instruction going over the limit from padded
guillemets during the initial pass). Plus one widget test: booting with
`ays.locale = 'it'` renders the home screen in Italian.

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
