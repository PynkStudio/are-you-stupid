---
tags: [product, ads, monetization]
updated: 2026-09-06
---

# Monetization and Ads

## Current state

**Real ads, via AdMob.** `AdMobAdProvider` (`lib/services/ads/admob_ad_provider.dart`)
wraps the Google Mobile Ads SDK and is wired in `main.dart`. `MockAdProvider`
still exists and is the default inside `AppServices` — used by every test and
by anyone running the app without touching `main.dart` — so nothing about
local dev changed.

**Real AdMob IDs are wired in**, publisher `ca-app-pub-6747636382023443`, one
app per platform:

| | iOS | Android |
|---|---|---|
| App ID | `...~5135428055` (`Info.plist`) | `...~7869402600` (`AndroidManifest.xml`) |
| Interstitial unit | `...6256938037` | `...7277893168` |
| Rewarded unit | `...8479294195` | `...7166212524` |

Full IDs live in `lib/services/ads/ad_unit_ids.dart` (ad units) plus
`ios/Runner/Info.plist` and `android/app/src/main/AndroidManifest.xml` (app
IDs). These are not secrets — they're public identifiers baked into the app
binary, the same as a bundle ID — but if the AdMob account ever changes,
update all three files together.

`rewardedDoubleXp` shares the rewarded unit ID with `rewardedContinue` (see
"Not implemented on purpose" below) — give it its own unit only if it
actually ships.

## The abstraction

`lib/services/ads/ad_provider.dart`

```dart
abstract class AdProvider {
  Future<void> initialize();
  Future<void> preload(AdPlacement placement);
  bool isReady(AdPlacement placement);
  Future<bool> show(BuildContext context, AdPlacement placement);
}
```

`AdPlacement { interstitial, rewardedContinue, rewardedDoubleXp }`.

To plug in a different network (AppLovin / ironSource / mediation): implement
`AdProvider`, pass it to `AppServices.boot(adProvider: ...)` in `main.dart`.
**No other file changes.**

`isReady` is the offline contract: it must be `false` whenever `show` would
have nothing to display (no network, no fill, still loading). Every caller
that offers the player an ad-gated action checks it first — see below.

## Offline behaviour

**The game is offline-first; ads are not, and that's fine.** The core loop
(gameplay, scoring, settings) needs zero connectivity, per
[[Game Design Pillars]]. Ads are the one deliberate exception, because a
network round trip is what an ad *is*.

The rule this produces: **no dead-end ad buttons.** If there's no connection
(or the ad hasn't finished loading, or AdMob has no fill), the corresponding
button does not appear at all — the player is never invited to tap something
that fails. `GameOverView.canContinue` is
`!state.continueUsed && AdManager.isRewardedContinueReady`, so the CONTINUE
button only renders when a rewarded ad is actually sitting there ready to
play. If the interstitial isn't ready when TRY AGAIN is tapped,
`AdManager.maybeShowInterstitial` just no-ops and the run restarts —
restart speed always wins (see Guardrails below).

## User-initiated only

**No ad ever appears without a direct tap from the player.** There is no
timer-based, launch-based, or background-triggered ad anywhere in this app —
only:
- the interstitial, fired from `_retry()` when the player taps TRY AGAIN;
- the rewarded continue, fired from `_continueWithAd()` when the player taps
  CONTINUE.

Any future placement must follow the same rule: wire it to an explicit tap in
the UI layer, never to a lifecycle event or a delay.

## The policy (`AdManager`)

Policy lives in one class, not scattered in the UI:

- **Never on launch.** The counter starts at zero and only increments on a
  *finished* run.
- **Never during gameplay.** Interstitials fire when the player taps TRY AGAIN,
  i.e. strictly between runs.
- **Every 3 finished runs** (`_runsBetweenInterstitials`), then the counter
  resets.
- **Rewarded continue**: offered once per run on the Game Over screen. Watching
  resumes the same level. Runs continued this way are recorded with
  `countAttempt: false` — see [[State and Persistence]].

## Not implemented on purpose

`rewardedDoubleXp` is wired in the enum and `AdManager`, but there is **no XP
system in the MVP**, so nothing calls it. Wire it up only if an XP/progression
system ships — otherwise it is a button that lies.

**"Remove ads" IAP is planned, not built.** When it ships, the shape should
be: a `noAdsPurchased` flag in `SettingsManager` (mirrors how `roastsEnabled`
already works), checked once in `AdManager` — `shouldShowInterstitial` and
`showRewardedContinue`/`isRewardedContinueReady` short-circuit to "no ad" when
it's set. That keeps the purchase a pure gate in front of the existing policy
rather than a second code path. Store integration (`in_app_purchase` package,
receipt validation) is out of scope until this is actually built — don't add
the flag before there's a purchase flow to set it.

## Guardrails

The MVP restart target is **under one second**. If a future ad integration adds
latency to TRY AGAIN, preload harder or drop the placement. Restart speed beats
ad revenue: it is what makes the loop addictive ([[Game Design Pillars]]).
