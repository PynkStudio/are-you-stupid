---
tags: [product, ads, monetization]
updated: 2026-10-02
---

# Monetization and Ads

## Current state

**Real ads, via AdMob.** `AdMobAdProvider` (`lib/services/ads/admob_ad_provider.dart`)
wraps the Google Mobile Ads SDK and is wired in `main.dart`, **only on
Android/iOS** — `google_mobile_ads` ships no macOS/Windows/Linux
implementation, and calling it there hangs `AppServices.boot` forever (the
platform channel has no native side to answer), leaving the app stuck on
the animated `SplashScreen` forever instead of reaching `HomeScreen` (see
[[Decision Log]] for why boot no longer blocks the first frame at all — it
just never resolves in this specific misconfiguration). `main.dart` picks
the provider with
`Platform.isAndroid || Platform.isIOS`; every other desktop target falls back
to `MockAdProvider`. `MockAdProvider` is also the default inside `AppServices`
itself — used by every test and by anyone running the app without touching
`main.dart` — so nothing about local dev changed.

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

## Consent (GDPR/UMP) and ATT

**Ads never start during the splash.** `AppServices.boot()` no longer
touches the ads SDK; `main.dart` calls `AppServices.startAds()` from a
post-frame callback once `HomeScreen` is on display. `AdMobAdProvider
.initialize()` then runs Google's required order:

1. **UMP consent** — `ConsentInformation.requestConsentInfoUpdate` (10 s
   timeout) then `ConsentForm.loadAndShowConsentFormIfRequired`. Mandatory
   for EEA/UK users since 2024; outside those regions UMP shows nothing.
   The message itself (GDPR, and optionally an IDFA explainer) is configured
   in the AdMob console → *Privacy & messaging*, not in code.
2. **ATT** (iOS only) — requested only after consent, with the app already
   active. iOS silently drops ATT requests made while the app is still
   launching, which App Review reports as "ATT prompt not found".
   It waits 900 ms after the consent form closes (a request made while the
   form is still animating away is dropped too) and is capped at 20 s: when
   iOS drops the request, the plugin only retries on the next
   `didBecomeActive`, and awaiting that unbounded once kept the SDK from
   starting at all.
3. **SDK start + preload** — only if `ConsentInformation.canRequestAds()`.
   Until then every `preload` is a no-op, so a player who declines simply
   sees no ads and no CONTINUE button (unless ads were removed).

When UMP reports `PrivacyOptionsRequirementStatus.required`, Settings shows
an **AD PRIVACY CHOICES** row (`AdManager.showPrivacyOptions()` →
`ConsentForm.showPrivacyOptionsForm`) so consent can be withdrawn, as GDPR
requires. Starting ads after a changed choice happens in the same call.

## The abstraction

`lib/services/ads/ad_provider.dart`

```dart
abstract class AdProvider {
  Future<void> initialize();            // consent → ATT → SDK (see above)
  bool get privacyOptionsRequired;      // GDPR: show "privacy choices"
  Future<void> showPrivacyOptions();
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

## Remove ads (IAP)

**Built.** A single non-consumable purchase, `ays_remove_ads`
(`IapProductIds.removeAds` in `lib/services/purchases/purchase_provider.dart`),
removes every ad permanently and works offline from the moment it's bought —
the same "no dead-end button" rule as ads applies to the buy/restore buttons
themselves (hidden, not disabled, when the store can't be reached).

**Restore is always visible** whenever the store is available, even while
the product hasn't resolved yet — App Review requires a restore path, and a
reinstall on a flaky connection must still get its purchase back. The
product is queried at boot (with a 4 s cap so a slow StoreKit never holds
the splash) and **re-queried every time Settings opens**
(`PurchaseManager.refreshProduct`), so a product that failed to load at
launch still appears later. A store call that throws (or refuses to start
the purchase) settles to `PurchaseFeedback.error` instead of leaving the
buy button disabled for the rest of the session.

**The abstraction** mirrors `AdProvider`/`AdManager` exactly:

```dart
abstract class PurchaseProvider {
  Future<void> initialize();
  bool get isAvailable;                    // false: hide buy/restore, same as ads
  PurchaseProduct? get removeAdsProduct;   // null until the store resolves it
  Stream<PurchaseUpdate> get purchaseUpdates;
  Future<void> buyRemoveAds();
  Future<void> restorePurchases();
  Future<void> refreshProduct();           // retried when Settings opens
}
```

`IapPurchaseProvider` wraps the `in_app_purchase` package (Android/iOS only —
`main.dart` picks it the same way it picks `AdMobAdProvider`, by
`Platform.isAndroid || Platform.isIOS`; every other platform gets
`MockPurchaseProvider`, which resolves every buy/restore instantly so the
settings flow is exercisable without store credentials, same role as
`MockAdProvider`).

`PurchaseManager` (`lib/services/purchases/purchase_manager.dart`) is the
*policy* layer — a `ChangeNotifier` the Settings screen listens to — and the
only thing that ever writes `SettingsManager.noAdsPurchased`. It never writes
it optimistically: only a `PurchaseUpdateStatus.purchased` or `.restored`
event from the provider's stream flips the flag. `AdManager` checks that one
flag and nothing else:

```dart
bool get shouldShowInterstitial =>
    !_adsRemoved && _scores.runsSinceAd >= _runsBetweenInterstitials;

bool get isRewardedContinueReady =>
    _adsRemoved || _provider.isReady(AdPlacement.rewardedContinue);
```

So once purchased: the interstitial never fires again, and rewarded continue
is granted for free without ever touching the ad SDK — which is also why it
keeps working with no connection. This is the one thing the purchase actually
buys the player: **the same functionality, minus the ad they'd otherwise have
to watch for it.**

**Restoring.** Required by App Store review guidelines for any non-consumable;
the Settings screen shows a "restore purchase" link next to the buy button.
Some stores stay silent on `restorePurchases()` when there is nothing to
restore, so `PurchaseManager` starts a 6-second timeout that surfaces "no
purchase found" if no stream event ever arrives.

**Store setup.**

- **App Store Connect: done.** App ID `com.ays.areYouStupid` is registered in
  the Apple Developer portal; the app record exists in App Store Connect as
  **"ARE YOU STUPID? - Reflex"** (Apple ID `6809188487`) — not the plain title,
  because "ARE YOU STUPID?" *and* "ARE YOU STUPID?!" were both already taken
  by other developers (App Store names are unique account-wide, and Apple's
  uniqueness check appears to ignore trailing punctuation). The non-consumable
  `ays_remove_ads` ("Remove Ads", Apple ID `6809188328`) is created under it:
  base price €2.99 (Italy/EUR base region), available worldwide, with the
  required English (U.S.) localization filled in. Only the English
  localization exists so far — add the other five once there's a reason to
  (see [[Localization]]); a missing localization for a store territory just
  falls back to English, it doesn't block anything.

  **This cannot go live yet.** Apple's Paid Applications Agreement on this
  account is not active (missing tax forms + banking details), and the
  updated Developer Program License Agreement needs the account holder to
  accept it. Both are pages only a human can complete (tax/banking data,
  agreement acceptance) — see [[Decision Log]] for the exact blockers found
  2026-09-06. The IAP metadata is ready and waiting; nothing else to do here
  once the account is unblocked, other than attaching it to a build submission
  ("Aggiungi alla verifica").

- **Google Play Console: not started.** Deliberately deferred — iOS ships
  first (see [[Decision Log]]). Same product id `ays_remove_ads`, type
  "Managed product", under Monetize → Products → In-app products, whenever
  Android setup resumes.

Until a store's product exists and its agreement is active,
`PurchaseProvider.removeAdsProduct` stays `null` there and the row simply
doesn't render — no crash, no dead button.

## Guardrails

The MVP restart target is **under one second**. If a future ad integration adds
latency to TRY AGAIN, preload harder or drop the placement. Restart speed beats
ad revenue: it is what makes the loop addictive ([[Game Design Pillars]]).
