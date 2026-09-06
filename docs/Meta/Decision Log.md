---
tags: [meta, decisions, adr]
updated: 2026-09-06
---

# Decision Log

Append-only. Newest last. One entry per non-obvious decision: what, why, and
what it costs. Never rewrite history — supersede it with a new entry.

---

### 2026-09-05 — Flutter, single codebase
Android + iOS from one codebase, no platform game engine. The game is text,
rectangles and timers: a game engine would be pure overhead and a much larger
binary. **Cost:** platform-specific ad SDKs need plugin wiring.

### 2026-09-05 — Zero external assets
No images, no fonts, no audio files. Everything is generated from widgets,
shapes, gradients and system sounds. **Why:** instant load, tiny binary, no
licensing, and the visual identity ("intentionally stupid but polished") is
easier to keep consistent. **Cost:** the store listing still needs artwork, and
sound design is limited to click/alert.

### 2026-09-05 — Challenges are data, not widgets
A `Challenge` produces a `ChallengeView` and decides what a tap means; a single
renderer draws it. **Why:** every challenge is testable headless, and a new
challenge is one class plus one registry line. **Cost:** a genuinely exotic
challenge may need a new layout in the renderer.

### 2026-09-05 — Input judged on pointer down
Not on tap (which fires on release). **Why:** the game lives or dies on feeling
instant. **Cost:** no "slide off to cancel" affordance — acceptable, and it fits
the joke.

### 2026-09-05 — Game Over is a layer, not a route
`GameOverView` renders inside `GameScreen`'s `Stack`. **Why:** TRY AGAIN
restarts in well under a second with no navigation. **Cost:** `GameScreen` is
the largest widget in the app.

### 2026-09-05 — Interstitials fire on TRY AGAIN
Not on entering Game Over. **Why:** the Game Over card is the moment people
screenshot; covering it with an ad would kill sharing, and the ad still lands
"after game over" as designed.

### 2026-09-05 — Fast streak instead of a second score
"HIGHEST STREAK" counts consecutive answers given in under 45 % of the time
limit. **Why:** a plain "correct answers in a row" streak would just duplicate
the level number.

### 2026-09-05 — `flutter run` for iOS fails in this working copy
The project lives in `~/Documents`, which is synced by iCloud Drive. The file
provider stamps `com.apple.FinderInfo` on copied frameworks and `codesign`
rejects them ("resource fork, Finder information, or similar detritus not
allowed"). Direct `xcodebuild` works because it signs inside DerivedData.
**Fix:** move the project out of the synced folder. See [[Getting Started]].

### 2026-09-05 — Project moved out of iCloud, iOS toolchain unblocked
Moved the checkout from `~/Documents/Unreal Projects/AYS?` to
`~/My project/AYS`. `flutter run` and `flutter build ios` now work; the
`codesign` failure above is gone. **Rule going forward:** this repository must
not live in an iCloud / Dropbox / Drive synced folder. The file providers stamp
`com.apple.FinderInfo` on copied frameworks and break iOS code signing, and the
failure mode looks like a Flutter bug rather than a filesystem one.

### 2026-09-05 — Real ads via AdMob; "offline first" now means the game, not the ads
Replaced the mock-only ad path with `AdMobAdProvider` (Google Mobile Ads SDK),
wired in `main.dart`. `MockAdProvider` stays as the default in `AppServices`
for tests and local dev. **Why:** the game itself must still boot and be fully
playable with zero connectivity — pillar 5 ("Offline first") is about the core
loop, not about monetization. Ads are the one deliberate exception: they need
a network round trip by nature.
**Rules that follow from this:**
- `AdProvider` gained `isReady(placement)`. Any UI that offers "watch an ad
  to X" must gate on it — see `GameOverView`'s `canContinue`, which now checks
  `AdManager.isRewardedContinueReady` in addition to whether the continue was
  already used. Offline (or no fill): the button simply doesn't render. No
  disabled button, no tapping into a dead end.
- Ads only ever fire from a direct player tap — TRY AGAIN for the
  interstitial, the CONTINUE button for the rewarded ad. Never on a timer,
  never on screen entry. This was already true of `AdManager`'s design; it is
  now a hard rule, not an accident.
- Shipped with Google's public **test** ad unit/app IDs (`ca-app-pub-3940256099942544/...`)
  in `AdUnitIds`, `ios/Runner/Info.plist` and
  `android/app/src/main/AndroidManifest.xml`. These must be swapped for real
  AdMob IDs before store submission — see [[Monetization and Ads]].
- iOS requires an App Tracking Transparency prompt before requesting
  personalized ads (`app_tracking_transparency` package, called from
  `AdMobAdProvider.initialize`) and a `SKAdNetworkItems` list in `Info.plist`
  (the 50 IDs Google currently publishes for AdMob).
- An ad-free IAP ("remove ads") is planned but not built yet — see
  [[Monetization and Ads]] for the intended shape so it isn't bolted on
  awkwardly later.

### 2026-09-06 — Swapped test AdMob IDs for the real account
Replaced every `ca-app-pub-3940256099942544/...` test ID from the entry above
with the real ones from publisher `ca-app-pub-6747636382023443` — a separate
AdMob app per platform, each with its own app ID, interstitial unit and
rewarded unit. Updated in lockstep: `lib/services/ads/ad_unit_ids.dart`,
`ios/Runner/Info.plist` (`GADApplicationIdentifier`) and
`android/app/src/main/AndroidManifest.xml` (`APPLICATION_ID`). Full ID table
in [[Monetization and Ads]]. **Not a secret** — these are public identifiers
shipped inside the app binary, safe to have in the repo and in docs, same as
a bundle ID.

### 2026-09-06 — Publishability audit: real release signing, project moved to git/GitHub
Audited the repo against [[Release Checklist]] and fixed what could be fixed
without external assets (icons, splash, privacy policy text are still open —
see the checklist).

**Android release signing.** `android/app/build.gradle.kts` had `buildTypes.release`
pointed at `signingConfigs.getByName("debug")` with a TODO — every "release"
build was debug-signed, which Google Play outright rejects. Generated a real
upload keystore (`android/upload-keystore.jks`, alias `upload`, 10000-day
validity per Google's own recommendation) and wired
`signingConfigs.create("release")` to read it from `android/key.properties`,
falling back to the debug config when that file is absent so a fresh clone
without the keystore still builds. Both files are gitignored — **never commit
them**. Verified with `apksigner verify --print-certs` on a real
`flutter build apk --release` output: the shipped cert fingerprint now matches
the upload keystore, not the debug one. Full reproduction steps and the PKCS12
store/key-password gotcha that broke the first attempt are in
[[Getting Started]].

### 2026-09-06 — Built the "remove ads" IAP
Implemented the shape sketched in the entry above, unchanged: a
`PurchaseProvider`/`PurchaseManager` pair mirroring `AdProvider`/`AdManager`
exactly (`lib/services/purchases/`), gating `AdManager.shouldShowInterstitial`
and `isRewardedContinueReady` on one flag, `SettingsManager.noAdsPurchased`.

**Why continue is granted for free rather than just hidden.** The alternative
— removing the CONTINUE button entirely once ads are gone — would make the
purchase a downgrade in one respect (no more free continues) to make up for
an upgrade in another (no interstitials). Granting it for free keeps the
purchase strictly additive: every feature the free player has, the payer keeps,
minus the ad they'd have watched for it. This is also why it stays available
offline — it no longer depends on the ad SDK at all once purchased.

**Why `PurchaseManager` never sets the flag itself on "buy tapped."** Only a
`purchased`/`restored` event from the platform purchase stream does. A
non-consumable bought on one device must restore for free on another via
`restorePurchases()` — writing the flag speculatively on tap would let a
canceled or failed purchase falsely unlock the game.

**Android needs `com.android.vending.BILLING`** in `AndroidManifest.xml` —
`in_app_purchase_android` doesn't work without it and there's no runtime error
that points at the missing permission, it just fails silently.

**Store products are not created by this repo.** Both App Store Connect and
Google Play Console need a product with the exact id `ays_remove_ads` before
a real purchase is possible on either store — see [[Monetization and Ads]].

### 2026-09-06 — App Store Connect configured for iOS; Android deferred on purpose
At the user's request, configured the App Store Connect side of the "remove
ads" IAP directly (via browser automation, logged into the user's own Apple
Developer account). Android/Google Play was explicitly **not** touched this
session — the user's plan is to ship iOS first, Android later, so there was
no reason to also block on Play Console setup yet.

**What exists now:** App ID `com.ays.areYouStupid` registered; app record
created in App Store Connect (Apple ID `6809188487`); non-consumable IAP
`ays_remove_ads` created under it (Apple ID `6809188328`), €2.99 base price,
worldwide availability, English localization. Full detail in [[Monetization
and Ads]].

**The app is not named "ARE YOU STUPID?" on the App Store — it's "ARE YOU
STUPID? - Reflex".** Both "ARE YOU STUPID?" and "ARE YOU STUPID?!" were
already registered by other developers when creating the app record; App
Store names are unique across the *entire* App Store, not just one account,
and the uniqueness check seems to ignore trailing punctuation (a plain "!"
wasn't a distinct-enough name). The user chose the "- Reflex" suffix from a
short list of alternatives when the plain name failed. This is the **App
Store Connect app name only** — it does not touch `CFBundleDisplayName` in
`Info.plist` (still "Are You Stupid", what's shown on the home screen icon)
or any in-app text. If this naming collision matters for branding later
(store listing vs. on-device name mismatch), that's a product call for
whoever ships this, not something this change tried to resolve.

**Found, but deliberately not touched:** the account's Paid Applications
Agreement is inactive (missing tax forms and banking details) and there's an
updated Developer Program License Agreement pending the account holder's
acceptance. Both require entering financial/tax data or accepting legal terms
— explicitly out of scope for an agent to do on the user's behalf. The IAP
metadata is fully configured and will work the moment the user clears these
two items themselves; nothing on the code or App Store Connect side is
blocking on anything else.

**Android launcher label.** Was `are_you_stupid` (the raw package name,
shown under the icon on the home screen). Changed to `Are You Stupid`, now
consistent with iOS's `CFBundleDisplayName`.

**Version control.** The project had no `.git` at all — no history, no
backup, no rollback. Initialized git and pushed to a new **public** GitHub
repo, `PynkStudio/are-you-stupid`. `CLAUDE.md` and `AGENTS.md` are
intentionally gitignored: they're internal agent operating instructions, not
part of the public-facing project, and the public README stands on its own.
**Cost:** anyone working on this repo from a fresh clone of the GitHub remote
won't have those files — this vault (`docs/`) is what carries the project
memory instead, which is exactly what [[Documentation Rules]] already assumes.

### 2026-09-06 — Privacy policy and support page live on the PynkStudio site
Closed the "privacy policy text" gap flagged in the audit above. The game now
has a public case-study page on the agency's own site (a separate repo,
`PynkStudio/BePork`, not this one): `pynkstudio.eu/lavori/are-you-stupid`, with
a full English privacy policy at `pynkstudio.eu/lavori/are-you-stupid/privacy`.
**Why there and not in this repo:** the app itself ships no web content
([[Documentation Rules]] / offline-only pillar), and Apple/Google both require
a public URL, not an in-app document, for the App Store Connect "Privacy
Policy" / "Support URL" fields and the Play Console "App content → Privacy
policy" field.
**What the policy actually says**, derived from the real state of this repo
(`pubspec.yaml`, `Info.plist`, `AndroidManifest.xml`, [[Monetization and
Ads]]): no account/backend/analytics; local-only storage via
`shared_preferences`; the only data leaving the device is what Google AdMob
collects for ads (IDFA/Advertising ID, IP, device info, ad interaction),
disclosed with the iOS ATT prompt and Android ad-settings opt-out; not
directed at children given the game's language, so explicitly out of Apple's
Kids Category and Google Play Families.
**Still open before submission:** wire these two URLs into the actual App
Store Connect and Play Console listings (this only prepared the pages, it
didn't submit anything), and consider adding a "Privacy Policy" link on the
in-app Settings screen (`lib/ui/screens/settings_screen.dart`) once the game
is ready to publish — there isn't one today.

### 2026-09-06 — Localized into IT/FR/ES/PT/DE with a hand-rolled string table
The app now ships in English, Italian, French, Spanish, Portuguese and
German. Built a small pure-Dart layer (`lib/i18n/`: `AppLocale`, `Strings.t`,
one flat string map per language) instead of the standard
`flutter_localizations`/ARB/`gen-l10n` pipeline. **Why:** `AppLocalizations.of(context)`
needs a `BuildContext`, but challenges are built by a plain function
(`ChallengeTemplate.build`) that never sees a widget tree — [[Architecture
Overview]]'s "`core/` and `challenges/` never import Flutter" rule would have
to be broken or bridged around either way, and the custom layer does it with
**zero new dependencies**, matching this repo's existing "only
`shared_preferences` and `share_plus`" stance ([[Getting Started]]).
`ChallengeParams` gained an `AppLocale locale` field defaulting to English, so
every pre-existing call site (all of `test/`) kept compiling and behaving
identically without changes.

Five challenges (`tap_word_button`, `tap_nothing_button`, `odd_word_out`,
`opposite`, `spell_count`) use English words as the actual gameplay, not UI
chrome, so those were **re-authored per language**, not machine-translated —
see [[Localization]]. `spell_count` is the sharp edge: the letter count of a
number word is language-specific (Italian "QUATTRO" is 7 letters, not 4), so
its whole answer key was recomputed by hand for every language rather than
translating the English words while keeping the English counts.

**Cost:** nothing enforces that all six `lib/i18n/strings_*.dart` files stay
in sync except `test/localization_test.dart`'s key-parity test — a key added
to only one file silently falls back to English in the other five rather than
failing loudly. Italian, French and Spanish were translated with high
confidence; Portuguese and German are solid working translations but have
**not** been checked by a native speaker — worth a pass before either
language appears in store marketing copy.

### 2026-09-06 — Fixed: macOS run hangs on a black window at boot
`main.dart` unconditionally built `AdMobAdProvider()` and awaited
`AppServices.boot`. `google_mobile_ads` has no macOS (or Windows/Linux)
implementation — `.flutter-plugins-dependencies` only registers it for `ios`
and `android` — so `MobileAds.instance.initialize()` called a platform
channel with no native side to answer it. The awaited `Future` never
completed, `runApp` was never reached, and the app sat on an empty black
window forever with no error printed. **Fix:** `main.dart` now picks
`AdMobAdProvider` only when `Platform.isAndroid || Platform.isIOS`, and
`MockAdProvider` otherwise — see [[Monetization and Ads]]. **Why this wasn't
caught earlier:** the project targets Android/iOS only ([[Getting
Started]]); `macos/` exists as a `flutter create` artifact developers use for
fast local iteration, and nothing had exercised that path since ads went from
mock-only to real AdMob.

### 2026-09-06 — Linked the PynkStudio site from Settings, closing the last privacy-policy gap
Closed the two "still open" items from the privacy-policy entry above: added
an "ABOUT THE GAME" row and a "PRIVACY POLICY" row to
`lib/ui/screens/settings_screen.dart`, opening
`pynkstudio.eu/it/lavori/are-you-stupid` and its `/privacy` page in the
device's browser via the new `url_launcher` dependency (`LaunchMode
.externalApplication`, not an in-app webview — nothing in this offline game
should own a `WebView`). Also added a small "Made by PynkStudio" credit under
the settings footer, linking to `pynkstudio.eu`.
**Why `url_launcher` and not something already in the tree:** `share_plus`
and `in_app_purchase` only pull in `url_launcher`'s platform packages
transitively; opening an arbitrary https link needs the front-facing
`url_launcher` API itself, so it's now a direct dependency.
**Android 11+ package visibility:** added a `<queries>` entry for
`android.intent.action.VIEW` + `https` to `AndroidManifest.xml` — without it,
`url_launcher` can silently fail to resolve a browser on modern Android. See
[[Services]].
**The case-study page picks its language from the app locale, the privacy
policy doesn't.** `_gameInfoUrlFor(AppLocale)` sends Italian players to
`pynkstudio.eu/it/lavori/are-you-stupid` and every other locale (English,
French, Spanish, Portuguese, German — none of the last four have a dedicated
page) to the `/en` page at the same path. **Caught mid-implementation:** the
`/en` page returned a 404 when this was first checked against the live site
(no hreflang alternate, no language switcher) — confirmed with the person who
owns `pynkstudio.eu` that it's being published there, so the app was wired to
the final URL ahead of the page going live rather than to a URL that already
resolved. **Verify `pynkstudio.eu/it/lavori/are-you-stupid/en` actually
resolves before shipping** — if it still 404s at release time, non-Italian
players tapping "ABOUT THE GAME" hit a dead link, which is worse than the
single-URL fallback this replaced.
The privacy policy stays one URL for every locale
(`.../are-you-stupid/privacy`) — it's deliberately English-only ("written in
English, the language of the app"), so there's no second version to route to.
The row label and the "made by" credit are translated into all six in-app
languages, same bar as the rest of Settings ([[Localization]]); only "PRIVACY
POLICY" is left untranslated everywhere, matching the policy page's own
English-only title.
**These two rows tip Settings into needing a scroll on common phone
screens.** The list already had one below-the-fold row (REMOVE ADS, see
[[Monetization and Ads]]) before this change; adding two more rows plus the
"made by" credit line (which sits outside the scrollable area, shrinking it
further) means the last row can land off-screen on a real device even when
REMOVE ADS itself is hidden (no store configured). Not a bug — the list was
already a `SingleChildScrollView` for exactly this reason — but confirmed the
hard way: verifying this on the iOS Simulator kept showing only one of the
two new rows no matter which one came last, until re-checking the screen
math against the existing "the row sits at the bottom of the settings list,
below the fold" comment on the REMOVE ADS test (`test/app_flow_test.dart`)
made it obvious this was scroll position, not a missing widget — the
background screen-automation tool used to inspect the simulator couldn't
synthesize a real touch-drag to scroll past it. `flutter test` confirmed the
row exists and works via `tester.ensureVisible`, which drives the actual
`ScrollController` rather than injecting a touch gesture.

### 2026-09-06 — Answered export compliance (encryption) once, in Info.plist
Added `ITSAppUsesNonExemptEncryption = false` to `ios/Runner/Info.plist`, so
Xcode/App Store Connect no longer asks the "does your app use encryption"
question by hand on every archive upload — it reads the answer straight from
the plist.

**Why `false` is the correct answer, not just the convenient one.** The app
only ever talks over standard HTTPS/TLS — the ad SDK, `in_app_purchase`
talking to the App Store, and `url_launcher` opening the PynkStudio pages, all
through the OS's own networking stack. Nothing in this codebase implements,
modifies, or bundles a proprietary encryption algorithm. That's exactly the
"exempt encryption" case under the U.S. EAR (Category 5 Part 2): using only
standard OS-provided HTTPS/TLS for internet communication, with no custom
crypto, qualifies for the exemption — hence `false` ("does not use
*non-exempt* encryption"), not a dodge of the question. If this ever changes
(a custom cipher, a VPN, peer-to-peer encrypted transport), this flag must
flip to `true` and an export compliance document gets filed with Apple before
the next submission.

### 2026-09-06 — English case-study page added; Settings picks it by locale
Closed the "all app locales link to the same, Italian-only page" gap flagged
two entries above. `PynkStudio/BePork` (separate repo) now has an English
sibling page at `pynkstudio.eu/it/lavori/are-you-stupid/en`, plus reciprocal
"Read in English" / "Leggi in italiano" links and an `hreflang` alternate
between the two. The privacy policy needed no change — it was already
English-only and is shared by both pages.

`lib/ui/screens/settings_screen.dart`'s `_gameInfoUrl` (a single hardcoded
constant) became `_gameInfoUrlFor(AppLocale locale)`: Italian → the Italian
page, every other supported locale (en/fr/es/pt/de) → the English one.
**Why English as the catch-all instead of a page per language:** the site has
five non-Italian in-app locales but building five more marketing pages for a
beta-stage game isn't worth it yet; English is the app's own source language
and the one the privacy policy already committed to, so it is the natural
fallback rather than a fourth option. The "PRIVACY POLICY" row is unaffected
— that URL was already language-agnostic.

**Not done:** dedicated French/Spanish/Portuguese/German pages. If any of
those markets becomes a real focus, add pages there and extend
`_gameInfoUrlFor` the same way, rather than translating all five up front.

### 2026-09-06 — Gentler level 1–2 speed ramp, timer bar hidden from level 6, one-off pace callouts
Playtesting feedback: new players were losing on level 1–2 before they'd
understood the game, and had no signal that the game was about to speed up or
that the timer bar would eventually disappear. Three small, independent
changes in [[Difficulty Curve]]:

1. `Difficulty.speedForLevel` no longer starts flat at `0.85` for levels 1–3.
   Levels 1 and 2 now ramp up into that same `0.85` (`0.60`, then `0.73`) —
   level 3 onward, and everything about how *hard* levels 4+ get, is
   byte-for-byte unchanged. This only touches how generous the very first two
   rounds are.
2. `Difficulty.showTimerBar(level)` hides the depleting bar from level 6 on —
   the same level `allowsTricks` unlocks mean templates — on top of whatever
   a challenge's own `showTimer` already decided. **Why level 6 and not some
   new threshold:** [[Game Design Pillars]] already ranks "timing" as the
   *last* source of difficulty, after misleading wording, fake buttons, etc.,
   and its own tuning rule says never make levels 1–5 harder — tying the cut
   to the existing `allowsTricks` boundary means this change can't
   accidentally violate a rule that predates it.
3. `Difficulty.milestoneKey(level)` returns a one-off callout shown via a new
   `GameState.paceNote` field (mechanically identical to the existing viral
   prompt): `FASTER NOW.` at level 4 (speed leaves the level 1–3 warm-up),
   `NO MORE TIMER.` at level 6 (explains #2 the moment it happens, framing it
   as an intentional new complexity rather than a bug). Both keys are
   translated in all six `strings_*.dart` files.

**Why not tested end-to-end in the running app.** `flutter analyze` and
`flutter test` (55 tests, all green, including new coverage in
`game_engine_test.dart` for the exact speed/timer/milestone values and a
widget test asserting the timer bar and no stray pace note at level 1) cover
the logic and the state wiring. A live check was attempted on macOS via
screen automation, but each round trip (screenshot, then a tap) took longer
than a single level's timer at this game's pace — by design, per
[[Game Design Pillars]]' zero-downtime rule — so no live screenshot of the
level 4 or level 6 moment was captured. Worth a manual playthrough before
shipping.

### 2026-09-06 — Fixed: wrong-answer sound was a silent no-op; added Android VIBRATE permission
The player reported that Settings shows sound/vibration toggles but nothing
actually plays. `SoundManager.wrong()` called `SoundBackend.alert()`, which
sent `SystemSoundType.alert` — checked against the Flutter engine source
directly (`shell/platform/android/.../PlatformPlugin.java` and
`shell/platform/darwin/ios/.../FlutterPlatformPlugin.mm`): neither embedder's
`playSystemSound` handles `alert`, it's silently dropped on both platforms.
This wasn't a settings/permission issue, it was dead code — `alert()` never
made a sound on any device, ever, since the 2026-09-05 "Zero external assets"
entry first described sound design as "click/alert" (that line was wrong from
day one, never verified against real device/engine behaviour).

**Fix:** removed `alert()`/`SystemSoundType.alert` entirely — `SoundBackend`
now only exposes `click()`, the one `SystemSoundType` either embedder actually
implements. `wrong()` is now two clicks 45 ms apart (`correct()` stays a
single click, `record()` keeps its existing 110 ms double-click) so it's still
audibly distinct without relying on a sound type that doesn't exist in
practice. See [[Services]] for the full breakdown of what each `SystemSoundType`
does per platform.

**Also added `android.permission.VIBRATE`** to `AndroidManifest.xml`. Not
proven strictly required by the public `View.performHapticFeedback` API docs,
but it's a normal permission (no runtime prompt, no Play Store disclosure
impact) and the standard fix for Android haptics silently doing nothing on
some OEMs — zero cost to add, only upside.

**What this doesn't fix:** `click`-based sound is inherently quiet and, on
Android, gated behind the system "Touch sounds" toggle — off by default on
many phones, invisible to this codebase. And haptics don't work on the iOS
Simulator or most Android emulators regardless of code — this needs
verification on a real device, not the simulator/emulator this session had
access to.

### 2026-09-06 — Wrong flash is now 2.85s and skippable, not 850ms
User feedback (playtesting on a real device): the roast shown after a mistake
was too fast to read. `GameEngine.wrongFlash` (`lib/core/game_engine.dart`)
went from 850 ms to 2850 ms, and a new `GameEngine.skipWrongFlash()` — wired
to a tap anywhere on the red flash (`FlashOverlay.onSkip`, with a small
"TAP TO SKIP." hint, `ui.game.tap_to_skip` in all six locales) — jumps
straight to Game Over. **Why skippable rather than just longer:** the "zero
downtime" pillar ([[Game Design Pillars]]) is about a player who already
knows the game not being made to wait; a returning player who reads roasts at
a glance still gets near-instant retries, while a new player gets the ~3x
longer default. `correctFlash` (240 ms) is untouched — nobody asked for it and
it isn't showing a line worth reading.

Updated everywhere the old 850 ms was written down: [[Game Engine]],
[[Architecture Overview]], [[Game Design Pillars]], and this repo's
`CLAUDE.md` (gitignored, but still the instructions the next agent reads).

**Test fallout:** three `game_engine_test.dart` assertions ticked exactly
900 ms past a mistake expecting `gameOver` — bumped to 2900 ms — and two
`app_flow_test.dart` "wait for timeout" windows (6 s / 7 s) were sized for
the old 850 ms flash on top of the *pre-[[Difficulty Curve]]-change* level-1
timing; both bumped to 9 s to clear the slowest starter's timeout at the new
level-1 speed (0.60) plus the full new flash, with margin. Added a dedicated
`skipWrongFlash` test (asserts it's a no-op outside the `wrong` phase too)
and a widget test that taps "TAP TO SKIP." mid-flash and confirms Game Over
lands immediately rather than after the full duration.

### 2026-09-06 — Fixed: the timer bar never actually rendered on a real device
Same feedback round: the depleting timer bar (added when [[Difficulty
Curve]]'s level-based visibility was introduced above) doesn't show up on
iOS. Root cause predates that change — it never worked, on any platform,
including this session's own earlier macOS screenshots, which showed the
same empty gap and were misread as "too subtle to see" rather than a bug.

`TimerBar`'s colored fill (`lib/ui/widgets/timer_bar.dart`) is a `DecoratedBox`
with no child, sized via `Expanded` inside a `Row`. A `Row`'s default
`crossAxisAlignment: center` gives its children *loose* cross-axis
(height) constraints; a childless `DecoratedBox` under a loose constraint
lays out at its constraints' smallest size — height 0. The outer
`SizedBox(height: 8)` fixes the `Row`'s own height, but that doesn't
propagate down to a centered, unstretched child. **Fix:** added
`crossAxisAlignment: CrossAxisAlignment.stretch` to the `Row`, which gives
children a *tight* height matching the `SizedBox` — one line.

**Why this stayed invisible internally too.** Nothing in the test suite
asserted the fill's actual rendered size — `TimerBar.visible` (the
`AnimatedOpacity` flag) was covered, but opacity 1 on a zero-height box is
still nothing. Added a regression test in `app_flow_test.dart`: finds the
`DecoratedBox` descendant of `TimerBar` and asserts its height is 8, not just
that `visible` is `true`.

**Found in passing, fixed same session:** verifying this surfaced a second,
unrelated overflow — see the "Fixed: intermittent overflow" entry in
[[Testing]] for `GameOverView`'s random-length roast/viral text blowing its
non-scrolling `Column` on an unlucky long pick, fixed with the same
`FittedBox(fit: scaleDown)` idiom already used for the level number.

### 2026-09-06 — Apple TV party mode: spec-first documentation pass
Before any multiplayer code, captured the full party-mode design in the vault
so no concept is lost between sessions: the versioned [[Multiplayer Protocol]]
(wire contract), [[Multiplayer Architecture]] (topology + host authority),
the two ends ([[Multiplayer Host (tvOS)]], [[Multiplayer Client (Mobile)]]),
the modes/rounds/TV language ([[Multiplayer Gameplay]]), the seeded challenge
contract + four new families ([[Multiplayer Challenges]]), the product scope,
ads, QR and sharing ([[Multiplayer Product]]), and the phased build + test
plan ([[Multiplayer Development]]). At this moment these are **design notes,
not descriptions of shipped code** — per the honest-docs habit in [[Documentation
Rules]], Home.md marks the feature *"Spec'd, not built"* and these notes get
bumped to match reality as each phase lands.
**Why spec-first:** the task's "do not lose important concepts before starting
development" is exactly what this vault exists for ([[Documentation Rules]] →
*Why this is enforced*).

### 2026-09-06 — Multiplayer: native SwiftUI tvOS app + Flutter controllers, not Flutter-on-tvOS
The party mode splits into a **sole-authority host** (a separate, native
SwiftUI tvOS app — [[Multiplayer Host (tvOS)]]) and **thin Flutter controller
clients** ([[Multiplayer Client (Mobile)]]) sharing only a versioned JSON wire
contract ([[Multiplayer Protocol]]).
**Why native SwiftUI for tvOS:** there is no clean, officially supported
Flutter→tvOS path for this codebase (different SDK surface, remote-focus
model, `NWListener`/Bonjour first-class on tvOS), and the host is a small,
display-focused app whose game rules all live behind the protocol anyway.
**Why thin clients:** the host being authoritative (room, seed, rounds,
countdown, validation, scores, elimination, winner) is what makes the
challenge-sync guarantee hold and removes any cheating surface ([[Multiplayer
Architecture]]). **Why JSON-over-TCP + Bonjour:** zero backend, zero internet,
pure LAN (offline pillar) — see next entry.
**Cost:** two codebases (Dart + Swift) maintain twin `ProtocolModel`s; the
heartbeat of correctness is that both stay mirror images of [[Multiplayer
Protocol]] — enforced by golden fixtures in the [[Multiplayer Development]]
simulation harness.

### 2026-09-06 — No backend, no internet: Network.framework + Bonjour over LAN
All multiplayer networking is **local-only**: host advertises
`_ays-party._tcp`, clients discover by room code, transport is plain TCP
(JSONL frames, [[Multiplayer Protocol]]), and room codes live only while the
host app runs ([[Multiplayer Product]]). No Firebase/Supabase/cloud websocket,
no accounts — consistent with the offline-first pillar ([[Game Design
Pillars]]) and the "no backend, on purpose" status in [[Home]].
**Accepted trade-off:** plaintext frames on the LAN and no host migration if
the Apple TV quits (MVP ends the match) — both deliberate, kept out of scope
(see the same product note). An automatic **grace window** (15 s) restores a
reconnecting player's state, which covers the realistic flaky-Wi-Fi cases a
party actually hits.

### 2026-09-06 — Multiplayer challenge sync = host picks, everyone rebuilds: `challengeId` + `seed`
Every client receives the **same** challenge because the host picks
`{ challengeId, seed }` once and broadcasts it; each end deterministically
rebuilds the canonical `ChallengeView` from those two values using the
existing 39-template registry ([[Multiplayer Challenges]]). This requires the
Phase 1 refactor — a template build path that accepts a seeded `Random`, without
changing `ChallengeGenerator` or single-player gameplay.
**Why not send full views over the wire:** the instruction/targets/colors are
large and already shared; sending id+seed keeps `ROUND_START` tiny and both
ends provably identical. **Why not let clients roll independently:** coordination
still guarantees sync, including across phones with different RNG state.

### 2026-09-06 — QR deep link encodes only a room code; host resolution via Bonjour match
The QR is `areyoustupid://join?room=7F4K` (4-char unambiguous alphabet). The
app opens on the deep link, then **resolves** the matching
`_ays-party._tcp` instance (room code = instance name) to find the host —
so the QR stays tiny and the manual `ENTER ROOM CODE` fallback reuses the exact
same resolution path ([[Multiplayer Architecture]]). The host also displays the
raw code under the QR as a typed fallback.
**Why not encode host IP:port in the QR:** an IP is long, not human-typable,
and rotatable (DHCP re-addressing invalidates stale QRs); Bonjour matching
keeps the code the single source of truth. Note this is a **spec decision** for
the tvOS build (not yet implemented) — if real-device testing shows Bonjour
resolution is flaky in large homes, the deep link can grow a `host=` param as
an additional resolution hint without breaking v1 clients (protocol handles it).

### 2026-09-06 — Multiplayer ads: never inside a match; cosmetic-only rewards
Controllers and the TV show **no ads during a live match** (rounds stay
uninterrupted). Ads may appear only at menu-return, before a new match, or
after a match ends; rewarded perks, if any, are cosmetic/bonus only — never a
competitive advantage ([[Multiplayer Product]] → Ads). This extends — doesn't
wedge — the single-player [[Monetization and Ads]] guards (still
user-initiated, still offline-safe). If a future "remove ads" IAP applies here,
it follows the same `PurchaseManager` pattern ([[Services]]).

### 2026-09-06 — Multiplayer Phase 1 landed: `buildFromSeed` is the canonical deterministic build, scoped to Dart for now
Phase 1 of [[Multiplayer Development]] is in: `lib/challenges/registry.dart`
now exposes `templateById(id)` (null for unknown ids — a future host treats a
bad id as a bad round, not a crash) and `buildFromSeed({challengeId, seed,
level, locale})`, which returns the canonical `Challenge` for a round. Same
tuple → same `ChallengeView`, guaranteed by `test/challenge_determinism_test
.dart` (deep-compares every render-relevant field across all 39 templates ×
four seeds × three level bands). `ChallengeGenerator` and single-player
behaviour are untouched — `buildFromSeed` is additive only.
**Why one function, not `Random(seed)` sprinkled at call sites:** the whole
point of the seeded contract is that the host, every phone *and* the
simulation harness rebuild the identical challenge. One entry point makes that
a property of the codebase, not of each caller remembering to seed correctly.
The `rng` is created fresh per call and never shared across rounds, so nothing
but `seed` (and the derived `level`/`locale`/`speed`) influences the result;
`speed` comes from `Difficulty.speedForLevel(level)` exactly as in solo play,
so no explicit speed needs to travel in `ROUND_START`.
**Deliberate scope cut — cross-language determinism is NOT solved yet.**
`Random(seed)` is deterministic within a Dart runtime, which covers every
Flutter phone and the in-process Dart harness (Phases 1–3). When the native
tvOS host ([[Multiplayer Host (tvOS)]]) needs its own rebuild to judge rounds
(Phase 4), two options exist and neither is chosen yet: (a) replicate Dart's
exact seeded stream in Swift so the host can rebuild locally, or (b) keep the
host from needing a local rebuild at all (e.g. judge from semantics the
protocol already carries). Revisit in Phase 4; this entry exists so nobody
assumes the Swift side "just works" by copying a seed. **Cost:** if (a) is
chosen, the Swift mirror must chase Dart's PRNG precisely, or the seed
contract becomes the protocol-level coupling point.
