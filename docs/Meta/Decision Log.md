---
tags: [meta, decisions, adr]
updated: 2026-09-15
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

### 2026-09-07 — Apple Intelligence dynamic game director: spec-first docs + branch
Before any AI code, captured the whole feature in the vault the same way the
multiplayer slice was (see the 2026-09-06 spec-first entry): 18 new
`docs/AI/` notes (router rows added in [[Documentation Rules]]), plus updates
to [[Home]], [[Roadmap]], [[Architecture Overview]], [[Services]], [[State
and Persistence]], [[Testing]], [[Getting Started]]. Work happens on a new
branch **`ai/dynamic-director`** cut from `multiplayer` @ `0282408`.
**Decisions locked in this pass** (each has a dedicated note):
- **The model is never the authority.** Every generation is a *proposal*;
  the deterministic Dart [[AI Challenge Validator]] is the only gate, and a
  served challenge is always validated ([[AI Challenge Validator]]).
- **Generated content is closed-vocabulary.** The model picks from
  `ChallengeMechanic`s the engine can render + judge; it never paints pixels
  and never sets floors ([[AI Challenge Generation]]).
- **Gameplay never blocks on the model.** Pre-generation cache + silent
  scripted fallback; a model failure is invisible to the player, and Settings
  is the only honest place the machine's state is shown ([[Pre-generation
  Cache]], [[Error States and Failure Communication]]).
- **On-device only, additive only.** Foundation Models via one MethodChannel,
  no server/analytics/identity; everything is opt-out of a *complete* scripted
  game and flips off with the `dynamicAIEnabled` master flag
  ([[Privacy and Offline]], [[Feature Flags]], [[Quality Neutrality and
  Guardrails]]).
- **Apple TV never runs the model.** `FoundationModels` has no tvOS support;
  one capable iPhone/iPad among controllers is elected AI Director Host
  ([[Multiplayer AI Director]]).
- **v1 model output is English-only**; all other locales play the fully
  localized scripted path ([[Localization and Language]]).
- **Unconfirmed API guesses dropped:** earlier session notes speculated about
  `GuidedGenerationRequest`, `DynamicProfileRequest`, `LanguageModelParameters`,
  `SessionUpdateConfigurationRequest` — the completed FoundationModels
  interface survey (module 1.5.2) confirms the real surface
  (`LanguageModelSession`, `SystemLanguageModel.default`, `@Generable`,
  `GenerationGuide`, ... — the tables in [[Foundation Models Integration]])
  and those names were discarded.
- The uncommitted multiplayer WIP (`lib/multiplayer/`, `test/multiplayer/`,
  `test/support/party_host_reference.dart`) was deliberately **not** included
  on the new branch — it's someone's in-progress work, kept untracked.

### 2026-09-07 — Multiplayer Phase 2 landed: protocol + client core + in-process host reference (test-only, never shipped)
Phase 2 ([[Multiplayer Development]]) is in: `lib/multiplayer/` carries the
full wire model + JSONL codec, the client session/state/controller, and an
in-memory transport; `test/support/party_host_reference.dart` implements the
**authoritative host** (gatekeeper, joining, ready gate, round orchestration,
countdown, judging, LSS lives/elimination/sole-survivor and Battle bonus
scoring, reconnect grace window) that the 32 headless tests in
`test/multiplayer/` run against. Three sub-decisions locked in with it:
- **The host reference lives in `test/support/`, not `lib/` or `tvos/`.** It is
  a reference for the rules, not the shipped host; the real host is the future
  native Swift target ([[Multiplayer Host (tvOS)]]). Keeping it test-side stops
  Dart and Swift competing as host implementations. **Cost:** two host
  implementations exist across the repo's life; the protocol is the single
  coupling point and the tests pin it.
- **Reconnect identity is `playerName` + `emoji`**, not a stored client id —
  no persistent identity exists in this offline product. The host re-sends
  `PLAYER_JOINED` (so the client re-learns its `selfClientId`) and broadcasts
  `PLAYER_RECONNECTED`. **Cost:** two phones using the same name+emoji down to
  collisions; acceptable at party scale and matches [[Multiplayer Product]].
- **Counting challenges commit a count, not replayed taps.** One
  `PLAYER_ACTION` per player per round is the protocol rule (duplicates →
  `DUPLICATE_ACTION`), so families like `tap_twice`/`tap_exactly_n` are
  answered `{ kind: "count", count }` and the host replays that count against
  its canonical challenge. **Cost:** two `PartyAction` kinds to model; the
  judge stays canonical regardless of timing.

### 2026-09-07 — macOS host is board-only (no direct play) with an AirPlay mirror button
The native host ([[Multiplayer Host (tvOS)]]) ships one shared Swift
`Host/`+`Net/`+`UI/` core for **tvOS and macOS**. On the Mac it is
**board-only by design**: it hosts, owns the rules and displays
lobby/rounds/results exactly like the TV, but the person at the Mac does not
play on the Mac — they use their phone like everyone else
([[Multiplayer Product]]). The macOS host adds an **AirPlay button** to mirror
the board to another screen; tvOS has no mirror button because the board *is*
its output. **Why:** most prospective groups don't own an Apple TV, but a Mac +
AirPlay covers them with zero extra surface; a Mac controller would be a second
input paradigm (keyboard/mouse/remote) that the 8-inch-tap game was never
designed for, and it would quietly fork the "TV is display-only" rule
([[Multiplayer Architecture]]). **Cost:** tvOS and macOS share every screen
and rule, so any tvOS-only shortcut (e.g. relying on remote focus) must be
abstracted; AirPlay latency is display-only and never touches judging, which
stays on the host clock ([[Multiplayer Protocol]]).

### 2026-09-07 — AI Phase 1 landed: the `ChallengeProvider` seam is synchronous by design
Phase 1 ([[Development Plan]]) is in: `lib/ai/generated_challenge.dart` +
`lib/ai/providers.dart` ship `GeneratedChallenge`, `ChallengeContext` and the
`Scripted/Adaptive/Fallback` providers; `GameEngine` now consumes
`ChallengeProvider` instead of a concrete `ChallengeGenerator`, and the UI
composes `FallbackChallengeProvider(scripted: ScriptedChallengeProvider(...))`.
**Decisions locked in with it:**
- **The engine-facing seam is synchronous — no `Future` in the contract.**
  The [[AI Challenge Generation]] spec sketch showed
  `Future<GeneratedChallenge?> nextChallenge(ChallengeContext)` with a
  `timeLimitSla`. That signature describes the *prefetch/warm* face, not the
  engine face: the game loop must never await the model, and the
  [[Pre-generation Cache]] design explicitly has the engine *pop* an already
  validated candidate synchronously (`cache.popNext() ?? scripted`). So the
  abstract seam is `GeneratedChallenge? next(ChallengeContext)`; the async
  model interaction arrives on `AppleAIService` (Phase 2) and the
  Director/prefetch loop (Phase 5), composed *behind* the Fallback. **Cost:**
  the spec snippet needed rewording to show both faces (done in
  [[AI Challenge Generation]]) so nobody re-introduces a blocking await into
  `_startLevel`.
- **`null` return means "nothing to offer right now".** AI providers
  volunteer `null` instead of erroring; the Fallback swallows nulls and always
  lands on scripted. The engine defends its end: on a top-level `null` it
  stays in the intro beat and re-asks next tick (release) with a debug assert —
  a broken composition shows as a stuck intro, never a crash.
- **The seam lives in `lib/ai/`, and `core/` may import it.** Both are pure
  Dart, so the "no widgets" rule ([[Architecture Overview]]) holds.
- **Locale now flows per-call** via `ChallengeContext`; the engine owns its
  own `locale` field and no longer writes into the generator. `Scripted`
  syncs its generator's locale from the context, so behavior is bit-identical.
- **Test suites unchanged in behaviour:** every assertion in
  `test/game_engine_test.dart` passes untouched; the three `GameEngine`
  construction sites gained the one-line provider wrap. The "never blocks,
  never crashes" property is what Phase 1 (and later suites) pin.

### 2026-09-07 — AI Phase 2 landed: challenge vocabulary, validator, and the on-device bridge
Phase 2 ([[Development Plan]]) is in: `challenge_vocabulary.dart`,
`challenge_validator.dart`, `apple_ai_service.dart` (Dart) +
`AppleAIService/` (Swift) — 61 AI tests green, `flutter analyze` clean, and
`tool/swiftc_ai_gate.sh` typechecks the Swift against the real SDK.
**Decisions locked in with it:**
- **A proposal and a challenge are two types, both in
  `generated_challenge.dart`.** `ChallengeProposal` is the *portable wire
  form* the model fills; `GeneratedChallenge` is the *built, playable* object
  the engine renders. The Swift `@Generable` structs mirror the proposal only;
  `GeneratedChallenge` is Dart's own construction so the seam
  (`challenge_provider.dart`) stays source-agnostic. Two types on the wire
  would let the model bypass the construction step — rejected.
- **`ChallengeProposal` is treated as untrusted.** It carries an envelope,
  candidate `correctAnswer`, and optional `difficulty`/`trickType`, but the
  deciding score is always the sealer verdict after the full
  `ChallengeValidator` pass — proposal fields are *candidates*, never applied
  as ground truth. The validator is the authority ([[AI Challenge Validator]]).
- **Trick contract: `allowTricks=false` permits `none` and `swap`.** The Phase
  0 spec sketch said "any trick type requires `allowTricks`"; the Difficulty
  ladder itself ships `swap` in the pre-trick band (`Difficulty.speedForLevel`
  floors), so banning `swap` would reject scripted-equivalent content the
  engine already serves. Locked: `requiresTrick` mechanics are invalid without
  `trickType != none`, and `trickType` must be in the mechanic's
  `allowedTricks`. Enforced by the validator, pinned by its tests.
- **`failLine` is keyed by `locale.name`, not `.code`.** `code` (`"en"`) rides
  in channel payloads; the validator looks up the fail line by the locale's
  *display name* (`"English"`) because that is the key the canonical mechanic
  fail lines are stored under. Two fields, two jobs.
- **`@Generable` cannot encode `[String: String]`, so `failLine` is not in the
  schema.** Probe-compiled against the iPhoneOS 26.5 SDK: a dictionary field
  fails with `'PartiallyGenerated' is not a member type of generic struct
  '…'`. The Swift provider will inject fail lines from the mechanic's
  canonical lines at build time ([[Foundation Models Integration]]), so the
  schema stays one-locale-field-free and the Dart validator keeps enforcing
  per-locale presence.
- **The API generation in this SDK is the *session* API, not the WWDC25
  preview.** `LanguageModelSession.respond(to:generating:options:)` +
  `SystemLanguageModel.default` (probe-verified): spec snippets written
  against `GenerativeModel`/`Text` do not compile here. The docs now show the
  verified forms; anything unverified (error-case names, sampling seeds) is
  re-checked in the phase that actually calls it (4–6).
- **Phase 2 ships `available` real; generation stubbed.** The Dart side is
  fully wired to the Wire contract (unitId UUIDs, error envelopes, bare
  booleans), `_startLevel` still only ever pops sync. The Swift controller
  answers `available` from `SystemLanguageModel.default.availability`,
  generation methods with `{ok:false, error:{code:"notImplemented",
  retryable:false}}` until Phases 4–5, `cancelUnit` true, `feedback` false.
  Cost: honest `unavailable` at the moment of a feature flag, no other
  observable change — the app is byte-for-byte scripted until a later phase.

### 2026-09-07 — Build number bumps automatically, not by hand
`scripts/bump_build_number.sh` increments the `+N` in `pubspec.yaml`'s single
`version:` line, and both platforms read the build number from that same
line — iOS via `Generated.xcconfig`, Android via `flutter.versionCode` in
Gradle. **Why:** a store submission with a reused build number is rejected,
and a manual bump is exactly the kind of step that gets forgotten under
release pressure. **Where it's wired:** the iOS `Runner` scheme's Archive
pre-action (fires on `Product > Archive` and on `flutter build ipa` — scheme
pre-actions run for both) and, on Android, a configuration-time hook in
`android/app/build.gradle.kts` gated on the requested task being
`assembleRelease`/`bundleRelease`. **Cost / gotcha:** the Android hook had to
run at Gradle *configuration* time, not inside a task's `doFirst` — the
`versionCode = flutter.versionCode` assignment in `defaultConfig` is
evaluated once, during configuration, so a bump that only runs at task
*execution* time would land one build too late. Every archive/release build
bumps unconditionally, including failed or abandoned ones — acceptable, since
a skipped build number is free and a reused one is not. See [[Getting
Started]].

### 2026-09-07 — Multiplayer Phase 3: two new dependencies, both minimal
`multicast_dns` (LAN room discovery) and `mobile_scanner` (in-app QR join) —
see [[Multiplayer Client (Mobile)]]. **Why these two:** the protocol note
already commits to plain `dart:io Socket` for the wire itself ("no new
dependency"), but discovery and QR scanning have no dart:io equivalent.
`multicast_dns` is pure Dart (dart-lang-maintained, no native plugin code —
keeps the "tiny binary" pillar); `mobile_scanner` is the standard camera-based
QR scanner and was chosen over relying solely on the OS Camera app's deep-link
handling because the canonical copy ([[Multiplayer Product]]) shows an
in-app `[ SCAN QR ]` button, not just a fallback. **Cost:** `mobile_scanner`
needs `NSCameraUsageDescription` (iOS) and `CAMERA` (Android);
`multicast_dns` needs `NSLocalNetworkUsageDescription` +
`NSBonjourServices` (iOS) and `ACCESS_WIFI_STATE` +
`CHANGE_WIFI_MULTICAST_STATE` (Android) — all added to
`Info.plist`/`AndroidManifest.xml` in the same change.

### 2026-09-07 — Android mDNS reception is an unverified real-device risk
`multicast_dns`, being pure Dart, never acquires Android's
`WifiManager.MulticastLock` — a real Android device is known to silently
drop incoming multicast packets without it, permission granted or not. This
wasn't worked around (no such lock API is reachable from pure Dart without
adding a platform-channel dependency) and hasn't been tested on real
Android hardware yet. **Decision:** ship it honestly flagged
([[Getting Started]] Troubleshooting) rather than claim untested behavior
works, and make it an explicit checkpoint for the Phase 10 real-device pass
rather than silently discovering it there.

### 2026-09-07 — No OS-level QR deep link in Phase 3, on purpose
Scanning the room QR with the system Camera app (rather than the in-app
scanner) and having it hand off straight into the app requires a registered
universal/custom URL scheme plus a deep-link listening package (`app_links`
or similar) — none of that shipped this phase. **Why it's fine:**
[[Multiplayer Development]]'s own phase plan already puts "QR deep-link →
join" under Phase 8 ("QR joining + polished lobby"), separate from Phase 3's
"scan/join/roster screens" — the in-app `mobile_scanner` camera view already
satisfies the canonical `[ SCAN QR ]` button for this phase. **Cost:** a
player who scans with their system Camera app today lands on a "not our
link" page/no-op instead of opening the game directly, until Phase 8.

### 2026-09-07 — The dev multiplayer host reuses the tested host reference, real-time
`tool/dev_multiplayer_host.dart` (a throwaway CLI for manually exercising
the Phase 3 client against a real socket, since the real host is Phase 4)
imports `test/support/party_host_reference.dart` directly rather than
hand-rolling a second host implementation. **Why:** that reference is
already the authority every Phase 2 suite proves correct against
`InMemoryPartyTransport`; the only thing standing between it and a real host
is that tests step its `FakePartyClock` manually. The dev tool instead
advances that same clock off a wall-clock `Timer.periodic` and wraps
accepted `ServerSocket` connections in the new `SocketPartyTransport` — no
protocol/scoring logic duplicated. **Cost / boundary:** it does **not**
advertise over Bonjour (see the mDNS entries above) — a correct RFC 6762
responder is real Phase 4 host work, not something to bolt onto a throwaway
script untested against a real Bonjour browser. The app's join screen gets a
`kDebugMode`-only manual `ip:port` field specifically to bridge that gap for
local testing — see [[Multiplayer Development]].

### 2026-09-07 — The mobile lobby never gets a START GAME button
Starting the match is TV/host-only authority ([[Multiplayer Product]] "TV —
lobby"); `mp_lobby_screen.dart` only ever shows a self READY toggle. **Why
called out explicitly:** it would be an easy, plausible-looking mistake for
a future change to add a "start" affordance to the phone UI (symmetric with
READY), which would violate "the host is authoritative" — [[Multiplayer
Protocol]] has no client → host message for it at all, so the client simply
has nothing to send.

### 2026-09-08 — RoomHost.swift ported to Swift as a testable Package target, not an Xcode app
`tvos/Sources/AYSHostCore/RoomHost.swift` is a faithful Swift port of
`test/support/party_host_reference.dart` — room lifecycle, gatekeeper,
round timing, action validation, both modes' scoring, elimination,
`GAME_END`. **Why a Package target and not a real tvOS/macOS Xcode
project:** this session has no tool that drives Xcode's project-creation
GUI or a tvOS simulator/build step, and hand-authoring a `.xcodeproj` blind
(unverifiable without either) risks shipping something broken and claiming
it works. The existing `tvos/` Swift Package (already how the Phase 2
protocol mirror was built) has none of that problem: `swift build`/`swift
test` verify it directly, no Xcode needed. **Cost:** the actual installable
app (SwiftUI `App`/`Scene`, tvOS remote focus, real `NWListener`/Bonjour,
signing) still needs a real Xcode target that only the user (or a future
session with Xcode-driving tools) can create — see [[Multiplayer Host
(tvOS)]] "Where the app shell itself stands".

### 2026-09-08 — RoomHost never rebuilds a challenge itself; ChallengeJudge stays an open seam
[[Multiplayer Challenges]]'s "Phase 4 open question" (replicate Dart's
seeded PRNG + all 39 templates in Swift, or keep the host from needing a
local rebuild at all) is explicitly **not resolved** by this port.
`RoomHost` depends on a `ChallengeJudge` protocol (`spec`/`judge`/
`judgeTimeout`) it never implements — every test drives it against a small
deterministic `FakeChallengeJudge` instead. **Why leave it open rather than
guess:** the two real options have sharply different costs (a full,
ongoing-maintenance PRNG+template port in Swift with real risk of subtly
wrong judging, vs. a fundamentally different host architecture that doesn't
independently verify answers) and the docs already flagged this as
undecided twice before this session touched it — picking one silently and
writing hundreds of lines against it would waste real effort if the other
was wanted. **What *is* resolved:** picking which `challengeId` plays next
doesn't have this problem at all — only the host needs to agree with
itself, since it simply tells every phone what it picked via `ROUND_START`
— so `ChallengePicker` ships as ordinary Swift randomness over a ported
copy of [[Challenge Catalog]]'s id/minLevel/weight/starter metadata (data,
not judging logic, so no cross-language risk).

### 2026-09-08 — RoomHost.attachClient: weak self, strong conn (not the other way around)
A real bug, not a hypothetical: the first version of `attachClient` weak-
captured *both* `self` and the per-connection `Connection` object in the
transport's `onLine`/`onDone` closures, relying on `self.conns` as `conn`'s
only strong owner. `AYSHostCoreTests` helpers that discarded the returned
`RoomHost` (`let (_, clients) = makeHarness(...)`, keeping only the simulated
clients) let the host deallocate immediately — after which every inbound
message on every connection silently went nowhere, no error, no crash,
just nothing. Traced by adding temporary prints at each layer and
bisecting which call sites actually fired; not something a first read of
the code would catch. **Fix:** `conn` is now captured **strongly** (its
lifetime should depend only on its own transport's closures, not on
bookkeeping elsewhere), `self` stays **weak** (correct — a connection must
never keep the whole host artificially alive), and the resulting `conn` ->
`transport` -> closure -> `conn` cycle is broken explicitly in a new
`detach(_:)` called from both `close()` and `onDisconnected`. **Why this
matters beyond the test suite:** the same shape of bug — an object's only
strong owner being an array on something that itself has no guaranteed
external owner — is exactly the kind of thing that would surface in the
real host too (e.g. a connection silently going deaf) if a future SwiftUI
integration doesn't hold `RoomHost` exactly right. See [[Multiplayer Host
(tvOS)]] "Testability story".

### 2026-09-08 — Speed became a stepped curve; heavier challenges got their own time budget
More playtesting feedback: even after the level 1-2 speed-up entry above,
the game still felt like it was accelerating too fast level to level, and
the tutorial (1-6) wasn't slow enough to actually teach the game. Rewrote
`Difficulty.speedForLevel` from the old continuous formula
(`1.0 + (level - 3) * 0.042`, capped at 2.35) to nine flat steps: 0.49 for
levels 1-2 (the most generous the game ever is) through five gentle nudges
across the 1-9 tutorial, then a step every ten levels from level 10 (where
the game is meant to start feeling "alive") up to an asymptote of 1.76 —
notably under the old 2.35 ceiling, so the endgame is also a little more
generous than before. Full table and reasoning in [[Difficulty Curve]].

**Why steps instead of tuning the same formula gentler.** A continuous
curve makes literally every level a bit different from the one before it —
that constant, imperceptible drift *is* the "it keeps getting faster"
feeling the feedback described, no matter how gently the slope is set. Flat
bands mean a run of levels plays identically, then visibly changes gear —
legible to a player in a way a slope never is, and it directly matches what
was asked for ("a scaglioni", not linearly).

**Why `base`/`floorMs` needed no new API.** The request also wanted an
explicit "this challenge never gets faster than X or slower than Y" per
challenge type, with the level's coefficient moving between them. That's
already exactly what `pace(base, floorMs: min)` does — `base` is the
longest a round ever runs (hit at level 1-2, where speed is at its lowest)
and `floorMs` the shortest (approached only past level 50) — the only
reason it didn't already feel that way is that `speedForLevel` used to dip
*below* 1.0 at low levels while a few challenges' `base` values were never
tuned to actually be "the most generous point." No new mechanism, no
touched call sites beyond the ones below — the seam was already there.

**Heavier challenges got a deliberate bump, not just the shared curve's
lift.** `math`, `spell_count`, `count_shapes`, `tap_exactly_n` and
`opposite` need a beat to actually think (arithmetic, counting a shape
soup, counting letters, recalling an antonym), not just react — their
`base`/`floorMs` in `lib/challenges/counting_challenges.dart` and
`word_challenges.dart` were bumped independently of the level curve, so
they carry more time than a same-difficulty color tap at *every* level, not
only at the start.

**The pace-note milestone moved with the curve.** `FASTER NOW.` used to
fire at level 4, back when the old formula's biggest early jump was
levels 3→4. With the tutorial now nine gentle, near-imperceptible steps,
level 4 no longer has a jump worth announcing — the real inflection is
level 10, so the milestone moved there. `NO MORE TIMER.` at level 6 is
unrelated (tied to `allowsTricks`, untouched) and stays put.

**Verification.** `flutter analyze` clean; `flutter test` green apart from
three pre-existing failures in `test/ai/telemetry_test.dart`
(`AdaptiveChallengeProvider`/`TelemetryCollector` — mechanic-selection and
profile-persistence assertions, unrelated to `Difficulty` and already
failing identically before this change; confirmed by grepping for any
`Difficulty` reference in that file's failing tests and finding none).
Rewrote `game_engine_test.dart`'s difficulty group for the new step table
and the relocated milestone. Specifically checked the two places a wrong
`speedForLevel` could do real damage: `challenge_templates_test.dart` computes
its own independent `speed: 1 + level * 0.03` rather than calling
`Difficulty`, so it was never at risk; `buildFromSeed` (multiplayer) does
call `Difficulty.speedForLevel`, but `challenge_determinism_test.dart` only
asserts two identically-built challenges produce the same duration as each
other, not a hardcoded value, so it stays green regardless of the exact
curve. The Swift protocol fixture's `durationMs: 8000` is a hand-written
literal for wire-format testing, not derived from real gameplay math —
confirmed unaffected by reading `tool/gen_protocol_fixtures.dart` directly.

**Still open: a separate real-device report that the timer bar disappears
after Game Over → RETRY and never comes back.** Investigated thoroughly —
rewired `AnimatedOpacity`/`TimerBar` lifecycle reasoning, added a targeted
`test/timer_bar_test.dart` that tears a hidden `TimerBar` out of the tree
entirely (matching what `GameScreen._buildBody` does when `GamePhase.intro`
replaces the `Column` with "READY?") and remounts a fresh visible one, and
extended `app_flow_test.dart`'s retry test to assert the real bar and its
rendered fill height after a full retry cycle — both pass. Could not
reproduce the report in either the widget tree or in isolation. Left
unresolved pending more detail from the user (does it reproduce without
first reaching level 6+, where the bar hides by design; does "restart" mean
the in-game RETRY button or relaunching the app).

**Follow-up, same session, after the user answered both questions:** it
reproduces below level 6, via the in-game RETRY button — ruling out the
"stuck from a previous hide" theory above outright, and matching a scenario
`app_flow_test.dart` already exercises and passes. Since the actual
mechanism still can't be reproduced in `flutter test` (no Impeller — the
Metal-backed renderer this app actually runs on via iOS, confirmed from a
build log line, "Using the Impeller rendering backend"; widget tests run
headless against a different, non-Impeller test binding), rewrote
`TimerBar` to remove the class of bug entirely rather than keep patching
the same fragile mechanism: instead of a `Row`/`Expanded` flex ratio sizing
a childless `DecoratedBox` (correct only if cross-axis stretch propagates
the way expected — the exact assumption that broke once already), it now
uses `LayoutBuilder` to read the real available width and gives a
`Container` an explicit pixel `width`/`height` directly. A widget sized in
real pixels can't fall into a "flex resolved to zero" trap on any rendering
backend, Impeller included, regardless of whether Impeller turns out to be
the actual explanation for the original report. Existing regression tests
(the DecoratedBox-height assertions in `app_flow_test.dart` and
`timer_bar_test.dart`) still pass unchanged, since `Container` with a
decoration still renders as a `DecoratedBox` internally — added a width
assertion alongside the existing height one for a bit more coverage. Still
not independently confirmed fixed on a real device — worth another check.

### 2026-09-11 — Phase 4 `Net/` + `QR/` landed; real-socket Swift tests are opt-in, not skipped-on-timeout
Closed two of the three "Not started" items under [[Multiplayer Host
(tvOS)]] Phase 4: `Net/` (`NWListenerServer.swift` — accepts `NWConnection`s,
optionally advertises `_ays-party._tcp` via `NWListener.service`;
`NWConnectionTransport.swift` — the real `HostTransport`, JSONL framing over
a socket, a line-for-line Swift mirror of
`lib/multiplayer/networking/session_socket.dart`'s `SocketPartyTransport`)
and `QR/` (`QRGenerator.swift` — `CIQRCodeGenerator` over the join deep
link, `CGImage` output so it stays UIKit/AppKit/SwiftUI-free and usable from
all three Apple targets). `RoomHost` needed no changes — both slot into the
`HostTransport` seam it already had.

**`Package.swift` needed an explicit `platforms:` list.** Adding
`async`/`await` code (`withCheckedThrowingContinuation`,
`withThrowingTaskGroup`) to a package with no declared minimum deployment
target failed to compile with `'isolation()' is only available in macOS
10.15 or newer` — SwiftPM was defaulting to a much older implicit target.
Added `platforms: [.macOS(.v13), .tvOS(.v16), .iOS(.v16)]`; also picked up
`OSAllocatedUnfairLock`-era APIs as available, though a plain `NSLock`-backed
`OnceFlag` (below) was used instead to keep the continuation-resume-once
pattern trivially portable.

**A captured `var resumed` in a state-update closure is a real Swift 6
concurrency error, not just a style nit.** Both `NWListenerServer.start`
and `NWConnectionTransport.connect` race a `stateUpdateHandler` callback
against a timeout `DispatchWorkItem` to resume one continuation exactly
once; under `-Xswiftc -swift-version 6` (not this package's mode today, but
the compiler already warns) a mutable `var` captured by two escaping
closures is rejected outright. Pulled the pattern into a tiny
`OnceFlag` (lock-guarded `tryFire() -> Bool`) instead of trying to prove the
closures happen to serialize on one queue — cheap, and it stops being a
land-mine if the queueing ever changes.

**The big one: `NWListener`/`NWConnection` hang forever in this session's
shell, and a `readyTimeout` cannot save you.** First attempt shipped
`NWListenerServer.start()` with no timeout — `swift test` hung indefinitely
the instant it reached the first real-socket test; `kill -9` was the only
way out. Root cause: on macOS, a plain command-line binary (not a signed,
installed `.app`) asking `NWListener` to *accept* inbound connections
triggers the OS's one-time "Local Network" TCC permission — normally a
GUI alert the user clicks Allow on. Inside this unattended shell there is
nobody to answer it, and the underlying XPC round-trip to the network
daemon blocks **synchronously**, on a thread from Swift concurrency's
shared cooperative pool. Second attempt added `readyTimeout` via
`withThrowingTaskGroup` racing the real wait against a `Task.sleep` —
still hung, because the blocking synchronous call can starve the *entire*
pool, including the sibling timeout task's own timer. Confirmed by
directly observing the stuck process with `ps`/`ps aux` (near-zero CPU
time over several minutes — genuinely parked, not spinning) across two
separate repro attempts.

**Resolution: gate at the test level, before touching `Network.framework`
at all.** `NWListenerServer.start(readyTimeout:)` keeps its timeout — it's
still correct, useful behavior for a real shipped host if a user taps Don't
Allow (`.failed`, delivered normally) or the OS is just slow. But
`NetworkTests.swift`'s four real-socket cases now check
`ProcessInfo.processInfo.environment["AYS_RUN_NETWORK_TESTS"] == "1"` via
`XCTSkipUnless` as the very first line, before any `NWListener` exists, so
`swift test` runs fast and green by default (32 `AYSHostCoreTests`, 4
skipped) instead of ever risking the wedge. Verified by explicitly opting
in (`AYS_RUN_NETWORK_TESTS=1 swift test`) and confirming it reproduces the
exact same hang (permission was never pre-granted on this machine either) —
so the gate is doing its job, not just hiding the problem. Whoever verifies
this for real needs an interactive Terminal, one click on the permission
dialog, then a full pass — the same one-time cost every real hosting app on
macOS/tvOS pays. This is the same category of "can't be verified headless"
gap [[Multiplayer Development]] already documents for `LanPartyDiscovery`
and reserves for Phase 10's real-device pass — not a new kind of problem,
just its first appearance on the Swift side.

**Also confirmed, in passing: an actual Xcode project is no longer
blocked.** [[Multiplayer Host (tvOS)]] "Where the app shell itself stands"
previously said nothing in-session could produce a real `.xcodeproj`. This
machine has `xcodegen` and `tuist` installed alongside a full Xcode 26.6
(tvOS 26.5 SDK) — `xcodegen generate` needs no GUI, just a `project.yml`.
The App/UI shell (still the only unstarted Phase 4 item) is scoping work,
not a tooling blocker, going forward.

### 2026-09-11 — App/UI shell generated with xcodegen, built and screenshotted live on both platforms
Same session as the `Net/`/`QR/` work above; the user explicitly asked to
act on the "an Xcode project is no longer blocked" finding rather than stop
there. Result: `tvos/project.yml` + `xcodegen generate` produces
`AYSHost.xcodeproj` with `AYSHost-tvOS` and `AYSHost-macOS` targets sharing
one `App/`+`UI/` SwiftUI source set against the `AYSProtocol`/`AYSHostCore`
package as a local dependency. Both targets build; both were run and
screenshotted for real (not just "compiles") — see [[Multiplayer Host
(tvOS)]] and [[Multiplayer Development]] Phase 4 for what the screenshots
showed. `AYSHost.xcodeproj` is committed (its `xcuserdata` isn't), matching
how `ios/Runner.xcodeproj` is already handled in `.gitignore` — this repo's
existing convention is to check in the generated project, not just the
spec, so anyone can open and build without installing `xcodegen`.

**`xcodegen`'s YAML has an undocumented landmine: an empty-dict Info.plist
property silently breaks the whole parser, with an error that doesn't name
the actual key.** First `project.yml` attempt included
`info.properties.UILaunchScreen: {}` (the standard way to opt into an
auto-generated launch screen). Every `xcodegen generate` failed with
`Parsing project spec failed: Decoding failed at "path": Nothing found` —
a message that points at a `path` key nowhere near the actual problem.
Bisected by deleting sections until a minimal spec parsed, then adding
pieces back one at a time (options block, settings block, a second package
product dependency — all fine) until reintroducing `UILaunchScreen: {}`
reproduced the exact failure in isolation. Root cause never fully
diagnosed (not worth the further time against a third-party tool's YAML
decoder), but the fix was simple: drop the empty-dict launch-screen key
entirely and use `INFOPLIST_KEY_UILaunchScreen_Generation: YES` as a plain
build setting instead, which xcodegen has no trouble with. **Takeaway:** if
`xcodegen generate` ever reports a `path`-related decode failure that
doesn't correspond to any actual `path:` key in your spec, suspect an
empty-dict (`{}`) value somewhere in `info.properties` first.

**`RoomHost` needed exactly one new seam to drive a UI: `onBroadcast`.**
Everything else the board needs (room code, roster, round/results/game-end
content) already existed as protocol messages `RoomHost` sends to
connected clients — the only gap was that the *local* app has no client
connection to itself. Added `public var onBroadcast: ((any PartyMessage) ->
Void)?`, fired from the existing private `broadcast(_:)` alongside the
real `conn.transport.send(wire)` loop — never for a single-connection
`send(_:_:)` (reconnect snapshots, per-seat `RoundResult`), only broadcasts,
since those are exactly the events a phone would also see. Deliberately
did **not** solve this by attaching a fake `InMemoryHostTransport` as a
phantom client — that would occupy a real seat and pollute
`seatCount`/roster/capacity logic for no reason. All 55 `swift test` cases
still pass after this addition (32 host-core, unchanged pass count),
confirming it's purely additive.

**The Info.plist `NSLocalNetworkUsageDescription` key is not just a nicety
— it appears to be *why* the real app didn't hit the CLI hang documented
above.** `project.yml` declares both
`INFOPLIST_KEY_NSLocalNetworkUsageDescription` and
`INFOPLIST_KEY_NSBonjourServices` as base settings. Both `AYSHost-macOS`
(launched as a real signed-ad-hoc `.app`, screenshotted via the
`computer-use` MCP's `app_screenshot` after `request_access`) and
`AYSHost-tvOS` (installed and launched on a booted `Apple TV` simulator via
`xcrun simctl install`/`launch`/`io screenshot`) bound a real
`NWListenerServer` and displayed the live port immediately — no permission
dialog blocked either one, unlike the bare `swift test` binary. Plausible
explanation: a real bundled app with a declared usage string gets the
normal one-time-if-ever OS prompt (or is simply pre-authorized in this
simulator/session context) instead of the synchronous XPC stall a
signature-less command-line executable hits. Not fully root-caused, but
empirically the App/UI shell's own networking is unblocked where
`NetworkTests.swift`'s `swift test` cases are not — the two situations are
different animals, and this is *not* evidence that `AYS_RUN_NETWORK_TESTS`
can be safely defaulted on for automated runs.

**tvOS platform download was explicit, not assumed.** `xcodebuild
-downloadPlatform tvOS` (multi-GB from Apple, several minutes) was run only
after asking the user directly, per this project's standing instruction to
treat any file/platform download as needing explicit permission — the
macOS target already proved the shared SwiftUI code worked before that
download was even requested, so the ask was scoped to "verify tvOS too,"
not a hidden prerequisite for the App/UI work itself.

**Scope check — what today's pass is not.** No second, real client
connected to either running host (so "waiting for players to join…" was
never exercised past that state), no ScoreboardView/EliminationCard/winner
animation/share card/humor lines (Phase 9), no XCTest target for the App
sources themselves (`RoomCode`, `DemoChallengeJudge` are covered only by
"it built and the live screenshot looked right," not assertions), and the
real `ChallengeJudge` decision is exactly as open as it was before —
`DemoChallengeJudge` lives in the App target specifically so it can never
be mistaken for progress on that question.

### 2026-09-11 — tvOS app icon catalog created, not wired into project.yml
`tvos/TVResources/Assets.xcassets/App Icon & Top Shelf Image.brandassets`
was generated from the root `icon.png` (App Icon small 400x240 + large
1280x768, both as Front/Middle/Back `.imagestack` layers — content only in
Back, Front/Middle transparent, i.e. no parallax since the source art isn't
layered — plus Top Shelf Image 1920x720 and Top Shelf Image Wide 2320x720),
letterboxed on black to fit the square source into tvOS's landscape icon
canvases. **Why not wired into `AYSHost-tvOS` in the same pass:** at the
moment of writing, `tvos/project.yml` had just been modified externally
(mtime seconds old) and no longer declared an `AYSHost-tvOS` target at all
— only `AYSHost-macOS` — contradicting this note's own "Structure (Swift)"
section above. Rather than race that edit or silently restore a target
someone else may have deliberately removed, the icon assets were left
unwired; asked the user, who confirmed: assets only, leave `project.yml`
alone. **Follow-up, whenever `AYSHost-tvOS` exists again:** add
`TVResources` to its `sources`, set
`ASSETCATALOG_COMPILER_APPICON_NAME: "App Icon & Top Shelf Image"` on that
target, and run `xcodegen generate`.

**Correction, same day, different session:** the "no `AYSHost-tvOS` target"
snapshot above was a transient mid-edit state from *this* session's own
`project.yml` debugging below, caught mid-write by a concurrent session —
not a deliberate removal by anyone. `AYSHost-tvOS` is present again (and
was never intentionally dropped); the follow-up steps above are unaffected
and still apply whenever someone wires `TVResources` in. Two sessions
editing `tvos/project.yml` around the same time is worth knowing about if
this happens again: re-read the file fresh immediately before every write,
and don't infer intent from a file that might just be mid-save elsewhere.

### 2026-09-11 — Real-device test found rooms undiscoverable: two separate bugs, one host-side one client-side
The user built `AYSHost-macOS` from Xcode and tried joining from a real
iPhone and iPad on the same Wi-Fi — the room never showed up. Two distinct,
unrelated bugs, both real:

**Bug 1 (host): `NSBonjourServices` never made it into the built
Info.plist at all.** `project.yml` had declared it as
`INFOPLIST_KEY_NSBonjourServices: _ays-party._tcp` — a plain scalar build
setting — but `NSBonjourServices` is a plist **array**, and
`INFOPLIST_KEY_*` synthesis can only express scalar values. Confirmed by
inspecting the actually-built `Info.plist`
(`/usr/libexec/PlistBuddy -c Print`): `NSLocalNetworkUsageDescription` was
there as a string, `NSBonjourServices` simply wasn't present at all — no
error, no warning, just silently dropped. Effect: `NWListenerServer` still
bound its TCP port fine (host showed "LISTENING ON PORT ..." correctly,
which is exactly why this passed this session's earlier live-screenshot
verification — that check only looked at the local bind, never asked
whether an actual phone could discover it), but it never actually
advertised `_ays-party._tcp` over Bonjour, so no client could ever find it,
same network or not.

Fix attempt #1 — `info.properties.NSBonjourServices: [_ays-party._tcp]` in
`project.yml` (the documented xcodegen way to inject array-valued Info.plist
keys) — hit a second, unrelated tooling bug: xcodegen 2.45.4 fails to parse
*any* array value under `info.properties` at all, with the same
misleading `Parsing project spec failed: Decoding failed at "path": Nothing
found` error this session already hit once for `UILaunchScreen: {}`
(see the `Package.swift`/`platforms:` entry above). Confirmed by bisecting
down to a minimal spec containing only that one array key. **Fix that
actually worked:** stopped using `info.properties` for this key entirely —
added a real, static `tvos/App/Info.plist` file (with `NSBonjourServices`
as genuine plist XML, plus `CFBundleShortVersionString`/`CFBundleVersion`
using the standard `$(MARKETING_VERSION)`/`$(CURRENT_PROJECT_VERSION)`
variable substitution) and pointed both targets at it via
`INFOPLIST_FILE: App/Info.plist`, excluding that file from the `App/`
`sources:` glob so Xcode doesn't also try to copy it as a resource (which
would conflict with `INFOPLIST_FILE` over who produces `Info.plist` in the
bundle). Verified with `PlistBuddy` that the built app now has
`NSBonjourServices` as a real array. **Takeaway for next time:** don't
trust `INFOPLIST_KEY_*` for anything beyond a single string/bool/number,
and don't trust xcodegen's `info.properties` for arrays either, on this
version — a real plist file is the reliable path for both array-typed keys
and empty-dict-typed keys (`UILaunchScreen: {}`).

**Bug 2 (client, real crash): `LanPartyDiscovery.resolveRoomCode` threw an
unhandled `SocketException` on a real iOS device instead of returning
null.** The user's device log showed
`SocketException: Send failed (OS Error: No route to host, errno = 65)`
from `MDnsClient.lookup` inside `resolveRoomCode`, propagating as an
unhandled exception out of `mp_join_screen.dart`'s `_connect`. Root cause:
the `multicast_dns` package talks mDNS over a raw `RawDatagramSocket`
(plain BSD socket), not `NWBrowser`/`NSNetServiceBrowser` — the higher-level
APIs iOS actually gates the "Local Network" permission prompt on. With that
permission not granted (denied once, or never actually prompted because a
raw-socket send doesn't reliably trigger the OS dialog the way the
higher-level frameworks do), the multicast send is refused at the OS level
with exactly this error, not a permission-denied error and not a clean
timeout. This is a real, previously-undocumented gap in
`lan_discovery.dart`'s "written and ready" claim
([[Multiplayer Client (Mobile)]]) — the function's own doc comment already
promised "returns null if nothing answers," but only guarded against
*timeout*, not against the socket itself failing. Fixed by catching
`SocketException` around the lookup in `resolveRoomCode` and returning null
the same as a timeout, rather than patching every call site — this is
where the "never throws, falls back to manual entry" contract is
documented, so it's where it should actually hold. `flutter analyze`
clean, `test/multiplayer/lan_discovery_test.dart` (pure `matchesRoomCode`
tests, unaffected) still green.

**Still to check, not something code alone can fix:** whether the iPhone
and iPad actually have "Local Network" granted for this app at all
(Settings → Privacy & Security → Local Network) — if it's off or was never
offered, no code change here makes discovery actually succeed, only
stops it from crashing while it fails. Worth the user checking that toggle
directly before re-testing now that both bugs above are fixed.

**Follow-up, same day: permission confirmed granted, but a *third* crash
appeared — `OSError: Address already in use, errno = 48` binding port
5353** (`MDnsClient.start` → `RawDatagramSocket.joinMulticast`), not caught
by the `on SocketException` handler above at all. `OSError` and
`SocketException` are siblings, not parent/child, in `dart:io` — catching
one doesn't catch the other, and this is a different failure than either
bug already documented. Confirmed `multicast_dns` 0.3.3+1 already passes
`reuseAddress: true, reusePort: true` internally on every bind
(`~/.pub-cache/.../multicast_dns-0.3.3+1/lib/multicast_dns.dart:119-120`),
so this isn't a missing flag on our side — `SO_REUSEPORT` only lets two
sockets share a port when *both* binders opted in, and iOS's own system
`mDNSResponder` already owns 5353 without necessarily doing so. Two
plausible causes, not mutually exclusive: (a) the app was under active
`flutter run` (JIT, hot-reload workflow per the device log) and a Hot
Restart doesn't close previously-opened native socket file descriptors —
only a full app relaunch does — so a prior `MDnsClient` from earlier in the
same dev session may have leaked a still-bound socket in the same running
process; (b) iOS's own mDNSResponder genuinely conflicts with this
package's raw-socket approach on this OS version regardless of app
lifecycle, a known category of `multicast_dns`-on-iOS report. Widened
`resolveRoomCode`'s catch to `on OSError` alongside `on SocketException`
(`lib/multiplayer/networking/lan_discovery.dart`) so this fails to null
same as the others rather than crashing — `flutter analyze` clean,
`lan_discovery_test.dart` unaffected.

**This is not fully resolved, and might not be resolvable from Dart at
all.** If a full app relaunch (not hot-restart) still hits this on a real
device, that's real evidence `multicast_dns`'s BSD-socket approach
genuinely cannot coexist with iOS's system mDNS responder here, which would
mean automatic Bonjour discovery is unreliable on real iOS hardware
independent of anything fixable in this codebase — the only way past that
would be a native platform channel using `NWBrowser` instead of a pure-Dart
package, real scope, not a bug fix. Told the user to (1) fully quit and
relaunch rather than hot-restart before concluding anything, and (2) in the
meantime use `mp_join_screen.dart`'s existing `kDebugMode`-only "DEV: HOST
ADDRESS" manual `ip:port` field (already built for exactly this — see
[[Multiplayer Development]] Phase 3) to keep verifying everything
downstream of discovery — socket connect, join, ready, round flow — without
depending on mDNS working on this hardware at all.

**Follow-up, same day: added a bind retry, and caught a self-inflicted bug
before it shipped.** The user reasonably asked whether trying a different
port, or cycling through several, could work around the conflict. It
can't — 5353 is mDNS's fixed protocol port (RFC 6762); every Bonjour
responder on the network, including the one advertising the room, only
ever talks on 5353, so a client listening anywhere else would simply never
see the traffic. What *can* help is retrying the same bind a few times
with a short delay, on the theory that "already in use" here may be
transient (a previous `MDnsClient` in this app process — plausibly from a
Hot Restart, which doesn't close native socket file descriptors the way a
full relaunch does — releasing the port a moment after the OS reported it
taken), not necessarily a permanent fight with iOS's system
`mDNSResponder`.

First implementation retried `client.start()` on **one** `MDnsClient`
instance across attempts — caught before shipping by actually reading the
package source (`multicast_dns-0.3.3+1/lib/multicast_dns.dart`) rather than
assuming retry-in-place would work: `start()` sets an internal `_starting`
flag before attempting the bind and only clears it on success; its own
guard (`if (_started || _starting) return;`) means calling `start()` again
on the *same* instance after a failed first attempt just silently no-ops
instead of retrying anything — attempts 2 and 3 would have done nothing,
looking like a working retry loop while providing zero actual retries.
Worse, reading further: `stop()` early-returns on `!_started` *before* ever
closing any socket a partially-completed `start()` already opened (e.g.
the IPv4 listener binds fine, then a later per-interface `joinMulticast`
throws, matching the user's exact stack trace) — a real resource leak
inside the package itself, and a plausible actual root cause of "address
already in use" persisting across supposedly-independent attempts, since
the previous attempt's already-bound socket is never released. Fixed by
constructing a **fresh `MDnsClient` per attempt** (`_bindWithRetries` in
`lan_discovery.dart` now returns the started client rather than taking one
in) — this doesn't fix the package's internal leak (this file can't reach
its private fields to force-close anything), but at least means each
attempt gets a real, independent bind try rather than repeatedly hitting a
guard that was silently doing nothing. `flutter analyze` clean, `flutter
test` unaffected (198 total, the same pre-existing 3 AI-telemetry failures,
0 multiplayer regressions).

**Honest bottom line:** this raises the odds of recovering from a
transient/leaked-socket condition within the same app run, but does not
and cannot fix a genuine, persistent conflict with iOS's system
`mDNSResponder` if that turns out to be the real, unfixable-from-Dart cause
per the entry above. Whether it helps at all is still unverified against
the user's actual devices.

### 2026-09-11 — Splash screen: boot moved after runApp, native launch backgrounds turned dark
Cold start used to show a blank white screen for as long as `AppServices.boot()`
took (`SettingsManager`/`ScoreManager`/`MultiplayerProfileManager.load()` plus
`ads.initialize()` — real AdMob SDK init on Android/iOS, which can run several
seconds — plus `purchases.initialize()`), because `main()` awaited the whole
chain **before** calling `runApp`: Flutter never got to draw a first frame
until boot finished, so the OS launch screen (hardcoded white in both
`android/app/src/main/res/drawable*/launch_background.xml` and
`ios/Runner/Base.lproj/LaunchScreen.storyboard`) just sat there. **Fix:**
`runApp` now fires immediately in `main.dart` with `AreYouStupidApp()` (no
`services`); `_AreYouStupidAppState.initState` kicks off `AppServices.boot()`
itself and `setState`s once it resolves. While `_services` is null, `build()`
returns a standalone `MaterialApp` showing the new `SplashScreen`
(`lib/ui/screens/splash_screen.dart` — a looping bouncing 🧠 emoji with
small yellow ✦ spark accents, `AnimationController..repeat()`, no images/
packages, consistent with the zero-external-assets pillar); once ready, it
returns `ServicesScope(services, child: MaterialApp(home: HomeScreen()))` —
same shape the app always had. Also recolored both native launch
backgrounds from white to `Ays.bg` (`#0B0B0F`) so the pre-Flutter native
splash matches the app instead of flashing white first. **A real bug this
caught:** the first version nested `ServicesScope` inside `home:` instead of
around `MaterialApp`; every screen reached via `Navigator.push` (GameScreen,
SettingsScreen, …) is a **sibling** route in the Navigator's overlay, not a
descendant of `home`'s subtree, so `AppServices.of(context)` threw "
ServicesScope missing above this widget" the moment any of them mounted —
caught by `test/app_flow_test.dart` failing with that exact assertion, not
by inspection. Tests are unaffected: `AreYouStupidApp(services: ...)` (what
every widget test passes) still renders the real UI on the very first frame
with no splash, since `_services` starts non-null and `_boot()` never runs.
**Cost:** the splash-to-home swap is an instant cut (a fresh `MaterialApp`),
not a cross-fade — a root-level `AnimatedSwitcher` was tried first but would
require `ServicesScope` to still wrap `home:`, reintroducing the bug above;
not worth chasing for a one-time, sub-second (on real devices) transition.

### 2026-09-11 — Real two-device test: core multiplayer loop confirmed working, isolating the remaining bug to discovery only
Using the `DEV: HOST ADDRESS` manual `ip:port` field (bypassing mDNS
entirely, per the previous entries' advice), the user connected a real
iPhone and a real iPad to the `AYSHost-macOS` app and started a match. Both
devices joined, readied up, and landed on **the same rendered challenge at
the same time** — the full chain this session's earlier work put in place
(`NWConnectionTransport` framing, `RoomHost` room/round lifecycle,
`ROUND_START` broadcast, the client's existing deterministic
`{challengeId, seed, level}` → `ChallengeView` build from Phase 1) is
confirmed correct end to end, for the first time, with real hardware and
no test double on either side. This isolates the earlier "room not found"
bug precisely to Bonjour/mDNS discovery — not the protocol, not the host,
not the client's challenge rendering.

**Worth being precise about what this does and doesn't prove**, since the
user's own read ("la modalità di gioco è tutta da creare ancora") slightly
undersold it: the *rendered challenge* both phones showed is real and
already shared correctly — `buildFromSeed` is exactly what single-player
uses, so there is no separate "multiplayer challenge rendering" left to
build. What's still fake is *judging the answer*: `RoomHost` on the Swift
side scores every submission through `DemoChallengeJudge`
(`tvos/UI/DemoChallengeJudge.swift`), a seeded coin-flip that has no idea
what the actual challenge is or whether either phone's tap was actually
correct — deliberately kept out of `AYSHostCore` so it's never mistaken for
progress on the real open question (port Dart's 39 templates' judging
logic to Swift, or keep the host from needing to). So: sync ✅, challenge
render ✅, real answer judging ❌ (random), and the whole game-show
scoreboard/elimination/winner UI (Phase 9) also ❌ — this test didn't
exercise any of that since `DemoChallengeJudge`'s fake verdicts aren't
tied to what either player actually did.

### 2026-09-11 — Replaced `multicast_dns` with `package:nsd`: LAN discovery now goes through native Bonjour/NSD, not a competing raw socket
The user made the right call: since real users can't use the `kDebugMode`
DEV-address fallback, automatic discovery has to actually work, and
retrying binds on a raw socket was always going to be a band-aid over the
real architectural problem — `package:multicast_dns` implements mDNS itself
over a plain `RawDatagramSocket`, competing with the OS's own Bonjour
daemon for port 5353 instead of asking it to do the lookup. Swapped to
`package:nsd` (5.0.1, MIT, 77 likes/160 pub points, actively maintained),
which wraps the actual platform APIs — `NsdManager` on Android,
`NSNetServiceBrowser` on iOS/macOS — so discovery goes through the same
mechanism the OS's Local Network permission is gated on and never binds a
competing socket at all. This should fix both real-device bugs from the
entries above at the root (the `SocketException`/`OSError` cases no longer
apply — they were specific to the raw-socket approach), not just make them
fail quieter.

**Verified this session, not assumed:** read the actual package source
under `~/.pub-cache` rather than trusting a web summary — `startDiscovery`,
`Discovery`/`Service`/`ServiceStatus`/`IpLookupType` shapes were confirmed
against `nsd_platform_interface`'s source directly before writing
`lan_discovery.dart` against them.

**API/semantics changed, not just the import.** `nsd`'s `Service.name` is
already the bare Bonjour instance name (e.g. `"7F4K"`) — unlike
`multicast_dns`'s raw PTR record domain strings
(`"7F4K._ays-party._tcp.local"`), there's no longer a domain suffix or
trailing-dot to parse around. `matchesRoomCode` was simplified from a
prefix-of-a-domain regex-adjacent check to a plain
case-insensitive/trimmed string equality — `test/multiplayer/
lan_discovery_test.dart` rewritten to match (trailing-root-dot and
prefix-collision cases dropped since they were specific to the old domain
format; a new null-service-name case added since `Service.name` is
nullable in the new API where the PTR string never was). `kAysPartyServiceType`
also dropped its `.local` suffix (`_ays-party._tcp`, matching
`BonjourService.serviceType` on the Swift host exactly) since `nsd`'s
`startDiscovery` takes the bare type, not a domain-qualified query string.
Manual SRV/A-record resolution (`_resolveInstance`) is gone entirely —
`ipLookupType: IpLookupType.any` makes `nsd` return real `InternetAddress`es
per service without any of that.

**Platform wiring:** `nsd`'s own README documents exact requirements, both
already met or added this session — iOS's `NSLocalNetworkUsageDescription`
+ `NSBonjourServices` were already present in `ios/Runner/Info.plist`
(unchanged, needed by `NSNetServiceBrowser` same as before); Android needed
`android.permission.INTERNET` added alongside the already-present
`CHANGE_WIFI_MULTICAST_STATE` (`android/app/src/main/AndroidManifest.xml`).

**A pre-existing, unrelated build break found and fixed along the way, not
caused by this change:** verifying the swap meant actually building for
both platforms, not just `flutter analyze`. iOS (`flutter build ios
--simulator --no-codesign`) succeeded outright. Android
(`flutter build apk --debug`) failed to even *compile* the Gradle script:
`android/app/build.gradle.kts:24` calls `exec { commandLine(...) }` to run
`scripts/bump_build_number.sh` before a release build, gated behind `if
(isReleaseBuild)` — but `Project.exec {}` was removed in Gradle 9 (this
project runs 9.3.1 / AGP 9.1.0, confirmed via
`android/gradle/wrapper/gradle-wrapper.properties` and
`android/settings.gradle.kts`), and a Kotlin build script fails to compile
on an unresolved symbol regardless of whether the branch containing it
would execute at runtime — so *every* Android build, debug included, was
broken, independent of anything in this session's own multiplayer work.
Fixed with a plain `ProcessBuilder(...).inheritIO().start().waitFor()`
instead of Gradle's own `exec {}` — zero Gradle-API surface to break
against on the next Gradle upgrade. `flutter build apk --debug` now
succeeds. Also surfaced (not fixed, not blocking): a Flutter warning that
`mobile_scanner` and `nsd_android` both "apply Kotlin Gradle Plugin (KGP)"
directly, which a future Flutter version will refuse to build — a
plugin-ecosystem migration (Built-in Kotlin) outside this repo's control
for now, tracked here so it isn't a surprise later.

**Verification:** `flutter analyze` clean; `flutter test` green apart from
the same 3 pre-existing, unrelated `test/ai/telemetry_test.dart` failures
(198 total, 0 multiplayer regressions); `flutter build ios --simulator
--no-codesign` and `flutter build apk --debug` both succeed with
`nsd`/`nsd_android`/`nsd_ios` linked in.

**Still unverified — this is a real fix candidate, not a confirmed fix:**
whether this actually resolves discovery on the user's real iPhone/iPad
against the Mac host hasn't been tested yet. It removes the specific
failure modes root-caused in the two entries above by construction (no
more competing raw socket), which is a much stronger basis for confidence
than the retry-logic patch was, but "should work by design" still needs a
real-device pass to become "confirmed working."

### 2026-09-11 — Resolved the "Phase 4 open question": the host stops judging content, the client does
Confirmed working (nsd fixed discovery), the user asked to make
non-AI multiplayer complete, which meant finally answering the question
[[Multiplayer Challenges]] and this log have flagged as unresolved since
Phase 4 began: how does the Swift host judge a tap against a
Dart-generated challenge? Every previous entry about `DemoChallengeJudge`
was explicit that it was a coin-flip placeholder, not a real answer.

**The decision, with the user's explicit sign-off after being shown the
trade-off (`AskUserQuestion`):** the host stops trying to judge content at
all. Porting all 39 templates' judging logic to Swift — much of it
genuinely time-dependent (moving buttons at ~400ms, colors that repaint
every ~0.4s, memory recall windows, swap traps) — would mean permanently
maintaining two implementations of the same rules in lockstep, which this
project has already been bitten by once this session (the round-auto-close
elimination-flag bug). Instead: the *client* judges, using the exact
`Challenge` engine single-player already has, fully tested, zero
duplication. It reports its verdict (`correct`/`reason`/`note`) in every
`PLAYER_ACTION`; the host trusts it, keeping only round lifecycle,
duplicate/stale/timing validation, scoring, lives, elimination, and
`GAME_END` — none of which ever needed challenge content in the first
place. Accepted trade-off, stated plainly to the user before the decision:
a modified client could self-report "always correct." Out of scope to
defend against for a local, in-person party game — the same posture this
project already takes toward offline/no-account design generally.

**What actually changed, layer by layer** (both Dart and Swift, kept in
sync as always):

- **Protocol** (`lib/multiplayer/protocol/protocol.dart`,
  `tvos/Sources/AYSProtocol/ProtocolModel.swift`): `PlayerAction` gained
  `correct: Bool`, `reason: String?`, `note: String?`. `correct` is
  `required` at the Dart call site (forces every sender to actually decide,
  no silent default) but decodes with `?? false` for forward tolerance,
  matching this protocol's existing philosophy. Golden fixtures regenerated
  (`dart run tool/gen_protocol_fixtures.dart`), both protocol test suites
  updated and green.

- **New: `PartyChallengeRunner`**
  (`lib/multiplayer/engine/party_challenge_runner.dart`). Drives one
  round's `Challenge` through `onStart`/`tick`/`tap`/timeout to exactly one
  verdict. **Deliberately owns no `Timer` or `Stopwatch`** — `tick(Duration
  elapsed)` is driven externally, exactly like `GameEngine.tick(delta)` is
  driven by `game_screen.dart`'s own `Ticker`. First implementation *did*
  own an internal `Timer.periodic` + `Stopwatch`, which seemed natural
  since the runner "drives itself" — caught before it shipped by actually
  working through what a synchronous `test()` body does with a `Timer`:
  nothing, since a plain (non-`fakeAsync`) Dart test never turns the event
  loop, so `commitCount`'s grace-window settle (`ExactTapsChallenge`'s
  420ms) would never fire in any test that doesn't literally sleep for real
  time. Moving the clock external (mirrors `FakePartyClock`'s role on the
  host side, and `GameEngine`'s own established pattern) means tests call
  `tick()` directly in a synchronous loop and production drives it from a
  real per-frame `Ticker` — same class, two different drivers, no
  `fakeAsync` needed anywhere.

- **`PartySession`** now owns the open round's runner: starts it on GO
  (`RoundCountdown` state `"GO"`), stops it on `RoundEnd`, exposes
  `tick(Duration elapsed)` (pass-through to the runner) and `submitTap`
  (forwards a `TapInfo`, tracks the last one for the wire message's
  informational `action` field). The runner's `onVerdict` callback is where
  `sendAction(...)` now actually gets called — callers don't send directly
  anymore.

- **`PartyController`** shrank to a pure `TapInfo` builder (resolving a
  tapped target's visual index from the round's `ChallengeView`) — judging
  and sending both moved into the session. `onCountCommitted` (dead code,
  its own doc comment said "absent until supported" — nothing ever called
  it) is gone; counting challenges are now driven tap-by-tap through the
  real `Challenge` exactly like the renderer already shows them, matching
  single-player exactly instead of a multiplayer-specific "commit a final
  count" shortcut that was never actually wired up.

- **`mp_game_screen.dart`** gained a `Ticker`
  (`SingleTickerProviderStateMixin`, same pattern as single-player's
  `game_screen.dart`) driving `session.tick(elapsed since GO)` every frame
  — this was a real, separate gap: even the *rendering* of time-dependent
  challenges (color shifts, moving buttons) was never actually ticked in
  multiplayer before this session, since nothing called `Challenge.onTick`
  at all on the client. Fixed as a side effect of wiring the runner in.

- **Both hosts** (`RoomHost.swift`, `test/support/party_host_reference.dart`)
  stopped calling into judging entirely. `onAction`/`_onAction` builds its
  verdict straight from the incoming `action.correct/reason/note`. The
  timeout fallback (a seat that never answers at all) is now a fixed
  "wrong, too slow" in both — previously the Dart reference genuinely
  replayed the challenge to judge a timeout correctly (e.g. `dont_tap`'s
  timeout-is-correct), which is exactly the divergent-implementation risk
  this change removes; a *functioning* client now always self-reports its
  own timeout verdict before going silent (the runner's `tick` reaching
  `challenge.duration` fires `onTimeout` locally, same path as a tap), so
  the host fallback only exists for a genuinely disconnected/crashed seat,
  for which "wrong" is the only reasonable default anyway.

- **`ChallengeJudge` (Swift)** shrank from three methods (`spec`, `judge`,
  `judgeTimeout`) to one (`spec`) — duration lookup and unknown-id
  rejection only. `DemoChallengeJudge.swift` (the coin-flip placeholder)
  is gone; renamed to `RoundDurationProvider.swift`, since what's left
  isn't a demo or a judge, it's a genuine small piece of production
  behavior now (one fixed duration for every challenge — real per-template
  durations are a real follow-up, not a blocker).

**A second real bug found by the new tests, same shape as the elimination
one earlier this session:** `SimClient.tap()` initially auto-fast-forwarded
`PartySession.tick` after *every* individual tap, including the
intermediate taps inside `commitCount(n)`'s loop — which meant a
multi-tap count sequence hit the challenge's own timeout after just the
*first* tap, since nothing but the settle window ever satisfies that
loop's exit condition and 15 more fast-forward calls stacked on top of
each other blow straight through to `challenge.duration`. Fixed by only
driving to settle-or-timeout once, after the *last* tap of a sequence
(`_rawTap` for intermediates, `tap` — which drives — only for the final
one); caught by actually reasoning through the loop rather than trusting
that "it compiled and the happy-path test passed."

**Verification.** Dart: `flutter analyze` clean; `flutter test` 200 total,
0 multiplayer regressions (2 new + 3 pre-existing unrelated AI-telemetry
failures only) — this included updating two `round_sync_test.dart` cases,
one `reconnect_test.dart` case, and two `simulation_test.dart` cases whose
premise depended on the *old* host-side timeout judging (a silent player on
`dont_tap` correctly judged as "correct" by the host); each now uses
`SimClient.letRoundTimeOut()`, the new equivalent of a real client
self-reporting. `flutter build ios --simulator --no-codesign` succeeded
after all changes. Swift: `swift test` 57/57 (4 still opt-in real-socket
cases, unrelated to this change); `xcodebuild` succeeded for both
`AYSHost-macOS` and `AYSHost-tvOS` after the `RoundDurationProvider`
rename.

**Not done in this pass, real follow-ups:** per-template round durations
(one fixed 6000ms for everything today); a real-device pass confirming the
new client-judged flow actually feels right end-to-end (only the harness
and simulator screenshots have exercised it); the App/UI shell's
ScoreboardView/EliminationCard/winner-animation/share-card/humor-line work
(Phase 9, unrelated to this change but still open).

### 2026-09-11 — Fixed 3 pre-existing AI test failures (unrelated to multiplayer), found during an audit
An audit pass (`flutter test`) surfaced three failures in
`test/ai/telemetry_test.dart` already flagged as pre-existing/unrelated in
several earlier entries, but never actually root-caused. Investigated and
fixed all three — `flutter test` is fully green (203/203) for the first
time this session.

**1. `AdaptiveChallengeProvider._targetMechanics()` returned every mechanic
in the profile, not a "struggling" subset.** Its own doc comment said "the
mechanics the player struggles at," but the implementation just sorted
*all* of them weakest-first with no actual filter — so `next()`'s
`targets.contains(mechanic)` acceptance check matched almost anything the
inner provider offered, since being *anywhere* in a full list is nearly
always true. Fixed by filtering to mechanics below the player's own
average success rate before sorting — a self-relative threshold that needs
no tuned constant and always leaves *some* mechanics classified as "fine"
even for a struggling player.

**2. A genuinely impossible test invariant, not a code bug.** "never
over-serves one mechanic within a window (variety guard)" fed the provider
an inner sequence with only 2 distinct ids ('a' 2/3 of the time, 'b' 1/3),
then asserted every id appears ≤3 times in every 8-item sliding window.
With only 2 ids and cap 3, an 8-window can hold at most 3+3=6 — the
assertion cannot pass for *any* implementation, by pigeonhole, independent
of reroll budget. Confirmed by manually tracing the reroll loop against the
exact fixture rather than assuming the failure meant the algorithm was
wrong. Fixed the test fixture to use 3 distinct ids (still ~2/3 'a', the
remaining third split between 'b' and 'c'), making the invariant
achievable (3×3=9 ≥ 8) and actually exercising the guard as intended.

**3. `TelemetryCollector`'s `profile` getter went stale across a run
restart.** `_recompute()` (rebuilds `_profile` from the in-run `_rounds`
window) was only ever called from `_observe()`, itself only called on
`GameEvent.correct`/`wrong`. `GameEvent.runStarted` cleared `_rounds` but
never called `_recompute()`, so `collector.profile` kept showing the
*previous* run's windowed `successRateByMechanic`/etc. until the next round
was actually observed — `totalRoundsPlayed` was unaffected either way,
since it's a separately-incremented all-time counter never derived from
`_rounds`. Fixed by calling `_recompute()` right after `_rounds.clear()` in
the `runStarted` case.

**Verification:** `flutter analyze` clean; `flutter test` 203/203, zero
failures — up from 200/203 (the 3 fixed here were the only ones failing).
No multiplayer code touched.

### 2026-09-11 — tvOS app icon wired into `project.yml`; uncovered and fixed a `CFBundleIdentifier`-missing regression
Two fixes landed together because the second was only found while verifying
the first.

**1. Orphaned icon catalog, closed out.** An earlier parallel session had
generated `tvos/TVResources/Assets.xcassets/App Icon & Top Shelf
Image.brandassets` but never referenced it from `project.yml`, so the
tvOS app built and ran with no icon. Fixed by adding `TVResources` to
`AYSHost-tvOS`'s `sources` and setting
`ASSETCATALOG_COMPILER_APPICON_NAME: "App Icon & Top Shelf Image"` on that
target only (`AYSHost-macOS` has no icon asset and is out of scope).
`xcodegen generate` + `xcodebuild` succeeded; `Assets.car` confirmed
present in the built bundle; a home-screen screenshot on the Apple TV
simulator confirms the icon renders next to Settings.

**2. While verifying the icon via `xcrun simctl install`, found the real
bug: `CFBundleIdentifier` was missing from the built tvOS `Info.plist`
entirely**, along with `CFBundleExecutable`/`CFBundleName`/
`CFBundlePackageType`/`CFBundleInfoDictionaryVersion`. `simctl install`
failed outright ("Missing bundle ID"); confirmed via
`PlistBuddy -c Print` on the built `Info.plist` that the key was genuinely
absent, while platform/SDK metadata Xcode auto-adds (`UIDeviceFamily`,
`MinimumOSVersion`, …) was present as expected.

Root cause: `tvos/App/Info.plist` is a real static file (see the
2026-09 entry on the `NSBonjourServices` array — `info.properties` can't
express arrays, so this project uses `INFOPLIST_FILE: App/Info.plist`
instead of `GENERATE_INFOPLIST_FILE` synthesis). A **static**
`INFOPLIST_FILE` does not get `CFBundleIdentifier`/`CFBundleExecutable`/
`CFBundlePackageType` etc. injected for free the way Xcode's own
*synthesized* Info.plist does — those keys have to be declared explicitly
(with the usual `$(PRODUCT_BUNDLE_IDENTIFIER)` etc. build-setting
substitutions). This had been true since the Bonjour fix introduced the
static file, but went unnoticed because `xcodebuild build` never checks
bundle identity — only `simctl install` / a real device install does. A
real, previously-undetected regression, not something introduced by the
icon work.

Fixed by adding the five missing keys to `tvos/App/Info.plist` with an
explanatory comment. Verified end-to-end after a clean DerivedData wipe:
`xcodebuild` succeeds, `simctl install`/`launch` succeeds on tvOS with
`CFBundleIdentifier` resolving to
`com.pynkstudio.areyoustupid.host.AYSHost-tvOS`, and the Lobby screen
renders correctly (QR code, room code, port, mode picker, ready count).
Also rebuilt and launched `AYSHost-macOS` from scratch after the change
(both targets share `App/Info.plist` via the base `INFOPLIST_FILE`
setting) — confirmed its `CFBundleIdentifier`
(`com.pynkstudio.areyoustupid.host.AYSHost-macOS`) and `NSBonjourServices`
are both present and the app launches as a live process.

**Verification:** `xcodebuild` clean build for both `AYSHost-tvOS` and
`AYSHost-macOS`; `simctl install`/`launch`/screenshot on Apple TV
simulator (Lobby UI + home-screen icon both confirmed visually); macOS app
launched and its Info.plist keys inspected directly. No Dart code touched;
`flutter analyze`/`flutter test` unaffected.

### 2026-09-11 — Real per-template round durations, replacing the flat 6000ms placeholder
`RoundDurationProvider` (the Swift host's only remaining `ChallengeJudge`
duty, since content judging moved to the client — see the Phase 4 entry
above) gave every one of the 39 templates the same fixed 6000ms deadline.
Flagged in an audit as a real gap: this value only matters as the host's
own fallback wait for a seat that never answers at all (a normal client
always self-reports well before it, since it runs the real, level-paced
Dart `duration`), but a flat 6000ms meant a stalled short challenge (e.g.
`tap_color`'s real ~1-2s at most levels) left the host hanging just as
long as a stalled long one (`count_shapes`'s real ~2-4s).

Replaced with a per-template `maxDurationMs` on `ChallengeCatalogEntry`
(`ChallengeCatalog.swift`) — the same struct that already carries each
template's `minLevel`/`weight`/`starter` for `WeightedChallengePicker`, so
this data now lives in exactly one place per template. `RoundDurationProvider.spec`
looks the id up there instead of returning a constant, and — as a free
side effect — now genuinely returns `nil` for an unrecognized challengeId
instead of blindly accepting anything (previously untested in practice,
since `RoomHost.startRound` is only ever called with `WeightedChallengePicker`'s
own catalog output; a real gap in strictness even though not currently
reachable).

Each `maxDurationMs` was hand-derived from the matching
`lib/challenges/*.dart` template rather than guessed: most templates are a
plain `p.pace(baseMs, floorMs: …)`, and since `pace` computes
`baseMs / speed` with `Difficulty.speedForLevel` bottoming out at 0.49
(levels 1-2, the slowest/most generous pace), `ceil(baseMs / 0.49)` is
that template's true worst-case duration *if it could ever be picked at
level 1* — deliberately not narrowed by each template's real `minLevel`,
since a slightly-too-generous fallback for a rare disconnect path is a
fine trade for not having to also mirror `Difficulty.speedForLevel`'s
level brackets in Swift. A handful of templates aren't a plain
`pace(base)` and were computed from their own formula instead
(`wait_for_green`, `precise_timing`, the three `remember_*`/`last_color`
memory templates whose duration includes fixed show/blank phases plus a
paced answer window, `tap_in_order`/`tap_reverse_order` whose base scales
with step count); `too_fast` isn't paced in Dart at all, so its value
(2600ms) is exact. See the inline comments in `ChallengeCatalog.swift` for
each derivation.

Added `ChallengeCatalogTests.swift` (4 new tests) asserting the catalog
still has all 39 entries, unique ids, and no zero/negative
duration/weight/minLevel — a tripwire for a future copy/paste slip, since
nothing else would catch a missing or malformed entry until a real round
somehow force-closed early.

**Verification:** `swift test` 61/61 (up from 57; the 4 new catalog
tests), `xcodebuild` clean build for both `AYSHost-tvOS` and
`AYSHost-macOS` after the change. No Dart code touched.

### 2026-09-11 — Full AI Director: scope audit, and Phase A (generated challenge runtime)
Starting the AI work deferred since the multiplayer session began. An audit
against `docs/AI/Development Plan.md` before writing anything found the
implementation stalled after Phase 2 (2026-09-07): the `ays/apple_intelligence`
bridge, the `@Generable` proposal schema, and the deterministic
`ChallengeValidator` all exist and are tested, but every Swift generation
method still returns `{ok:false, error:{code:"notImplemented"}}`, nothing in
`lib/ai/` ever calls the bridge, `FallbackChallengeProvider` is constructed
in `game_screen.dart` with only `scripted:` (its `ai:` slot is never
passed), and `AdaptiveChallengeProvider` — fully built and tested since
Phase 3 — is never constructed outside its own test file. **The shipped game
is 100% scripted today regardless of all the AI scaffolding.** Multiplayer
has zero AI code (Phases 7/8 unstarted).

Also found, planning the work: the docs specify the *shape* of a
`ChallengeProposal` (mechanic vocabulary, elements, one `correctAnswer`) but
nothing anywhere builds an actual playable `Challenge` from one —
`GeneratedChallenge` only ever wraps an already-built `Challenge`. Every
later phase (cache, commentary reuse, multiplayer AI rounds) needs this to
exist first, so it's the first piece landed, ahead of the doc's own
numbering.

**New file `lib/ai/generated_challenge_runtime.dart`**: `GeneratedChallengeRuntime`,
one generic `Challenge` (extends the scripted `BaseChallenge` scaffolding
from `lib/challenges/base.dart` rather than duplicating it) that dispatches
judging on `MechanicRef.action` instead of shipping a class per mechanic —
`buildFromProposal(proposal, {locale})` is the entry point, assuming the
proposal already passed `ChallengeValidator.validate` (this file does zero
re-validation, only interprets an already-trustworthy proposal).

**The proposal schema is thinner than several scripted templates it stands
in for**, so this is genuinely new design, not a port — decisions made and
why:
- **`donot_tap` (`dont_tap_odd`) mirrors `buildDontTapColor`, not
  `DontTapChallenge`.** The one named element is what to avoid; tapping any
  *other* real element passes, and a timeout with nothing tapped fails —
  an active "tap something safe" shape, since `dont_tap_odd`'s allowed
  tricks (`sequence`/`rule_flip`/`fake_button`) match trap templates that
  require engagement, not `dont_tap`'s pure do-nothing patience shape.
- **`tap_until_stop` (`spam_until_stop`) needs a tap-count goal the schema
  has no field for** (no timeline events beyond `difficulty`). Reused the
  scripted `SpamTapsChallenge.build` formula verbatim
  (`6 + min(6, level ~/ 5)`) so pacing feels identical to the hand-authored
  equivalent rather than inventing a new curve.
- **`tap_sequence` (`tap_second_order`, `sequence_grow_remember`) has no
  separate ordering field either** — the proposal's `elements` array order
  *is* the required tap order, mirroring `OrderChallenge` (`tap_in_order`),
  the closest scripted "walk a fixed sequence" shape. This is a real
  simplification for `sequence_grow_remember`, whose scripted analogs
  (`lib/challenges/memory_challenges.dart`'s show→blank→ask templates) have
  temporal phases the flat schema can't express; a single static ordered
  walk is what the current wire shape can actually support.
- **`tap_many` (`tap_every_but`)**: the one named element is the *excluded*
  one; passes once every other element has been tapped at least once,
  mirrors `buildIgnoreNext`/`buildDontTapColor`'s "all but one" correct set.
- **`failLine` lookup is keyed by ISO code (`"en"`), not the native display
  name.** The 2026-09-07 Phase 2 entry says "keyed by locale's display name,
  not `.code`," but every actual `ChallengeProposal.failLine` fixture in
  `test/ai/challenge_proposal_test.dart` (predating this session) uses
  `'en'` — that entry's "display name" language was describing an internal
  Swift-side canonical-fail-line map key, unrelated to what proposals
  actually carry on the wire. Went with what the existing fixtures and code
  already do (`.code` first, `.nativeName` as a defensive fallback) rather
  than reinterpreting a year-old entry against live test evidence.

New suite `test/ai/generated_challenge_runtime_test.dart` — 26 cases, one
group per action (pass/fail/background-tap/timeout for `tap`/`color_pick`;
avoid semantics for `donot_tap`; hold/release/wrong-target for `hold`;
completion order for `tap_many`/`tap_sequence`; goal-counting for
`tap_until_stop`), plus element→target/layout/duration rendering checks.

**Verification:** `flutter analyze` clean; `flutter test` 229/229 (up from
203 — the 26 new cases), no existing test touched. No Swift/multiplayer
code touched — this is single-player-shaped infrastructure only; a fully
scoped plan for the remaining phases (feature flags, commentary,
pre-generation cache, tool calling, and the multiplayer wire
messages/election/Director runtime) is saved and will land phase by phase,
each with its own analyze/test/docs pass.

### 2026-09-11 — AI Director Phase B: `AiFeatureFlags` data module
Landed early relative to the design doc's own numbering (there it's Phase
9, "Feature flags & modes") on purpose: every phase from here on
(commentary, cache, multiplayer director) needs a flag to read from the
moment it lands, and retrofitting gating into four already-shipped phases
later would be real rework for no benefit. Only the Settings UI screen
(the mode picker, the per-device availability copy) stays deferred to the
doc's Phase 9 slot — the flags themselves are fully live from today.

New `lib/ai/feature_flags.dart`: `AiFeatureFlags`, one `SharedPreferences`-backed
flag per [[Feature Flags]]'s table, plus `AiExperienceMode` (`genius` /
`focused` / `classic`) as a label `setMode()` writes across the flags it
controls in one call. Two implementation choices worth logging:

1. **The tri-state in the design doc (`enabled | disabled | unavailable`)
   is not what this module persists.** `unavailable` is a *device
   capability* fact (`AppleAiAvailability`, fetched async from the
   `ays/apple_intelligence` bridge) — it doesn't belong in a synchronous,
   `SharedPreferences`-backed struct. This file only ever persists
   `enabled`/`disabled`; whichever later phase combines a flag with live
   availability (the cache, the commentary provider) computes the
   "unavailable" overlay itself at the point of use.
2. **Every non-master flag getter ANDs itself with `dynamicAIEnabled`
   internally** (`aiCommentaryEnabled => dynamicAIEnabled && ...`), so a
   consumer never has to remember to check both — flipping the master
   alone is a complete, instant rollback, exactly as [[Quality Neutrality
   and Guardrails]]'s mitigation ladder requires. Sub-flag values are left
   untouched underneath the mask, so re-enabling the master (or switching
   `classic` back to `genius`/`focused`) restores whatever posture the
   player had instead of resetting it — `classic` is implemented as
   "flip only the master," not "flip every flag to false."
3. **`aiAdaptiveDifficultyEnabled` is excluded from the [AiExperienceMode]
   ladder entirely** — its default is off (the one flag that is), and
   `setMode()` never touches it in either direction. The design doc's
   Genius row says "AI challenges + commentary (+ adaptive if it's ever
   enabled)" — a parenthetical carve-out, not a forced-on default — so a
   player's own choice on this one flag survives every mode switch.

Key namespace: `ayu.dynamicAI.*`, matching `lib/ai/telemetry.dart`'s
existing `ayu.profile` — a deliberately different prefix from the rest of
the app's `ays.*` settings keys, an established `lib/ai/`-only precedent
this file follows rather than invents.

New suite `test/ai/feature_flags_test.dart` — 9 cases: documented defaults,
master-off short-circuits every sub-flag, sub-flag values survive a
master-off/on round trip, persistence across a fresh `load()`, the three
modes' exact flag postures, adaptive difficulty surviving every mode
switch, and an unrecognized persisted mode name falling back to `genius`.

**Verification:** `flutter analyze` clean; `flutter test` 238/238 (up from
229). No Swift/UI code touched — Settings UI wiring is explicitly deferred
to the doc's own Phase 9.

### 2026-09-11 — Correction: no actual `failLine` key discrepancy (Phase A entry above overstated it)
The Phase A entry above claimed the 2026-09-07 Phase 2 note ("`failLine`
keyed by locale's display name, not `.code`") conflicted with the real
fixtures using `'en'`, and picked `.code` over `.nativeName` to match. On
closer look while writing Phase 4: there's no actual conflict.
`AppLocale.code => name` (defined in `lib/i18n/app_locale.dart`), and
`AppLocale` never overrides Dart's built-in `Enum.name`, so `.name` and
`.code` are the *same getter call* today — both literally return `"en"`.
`ChallengeValidator._envelope` itself looks the fail line up via
`ctx.locale.name` (`challenge_validator.dart`), which is byte-identical to
`generated_challenge_runtime.dart`'s `.code` lookup. So the runtime's
lookup was already correct and consistent with the validator; the "display
name (English)" reading in the Phase A entry was my own misinterpretation
of a same-value distinction, not a real historical decision to reconcile.
No code change needed — leaving the runtime's `.code`-first lookup as is,
just correcting the record.

### 2026-09-11 — AI Director Phase 4: real `requestCommentary` + the Dart commentary ladder
`AppleAIController.requestCommentary` had been stubbed with
`{ok:false, error:{code:"notImplemented"}}` since Phase 2 (2026-09-07).
Implemented for real on both sides.

**Swift, new `ios/Runner/AppleAIService/CommentaryProfile.swift`**:
`AYSCommentaryService.requestCommentary(kind:locale:context:)`, mirroring
`AYSAppleAIAvailabilityRail`'s always-compiled-outer/`@available`-gated-inner
split — callable from any OS version, only actually touches
`LanguageModelSession` behind `#if canImport(FoundationModels)` +
`@available(iOS 26.0, *)`. Verified against the **real** iPhoneOS 26.5 SDK
in this environment (not just typechecked in the abstract): probed the
exact API surface with small throwaway `swiftc -typecheck` scratch files
before writing the real code, confirming
`LanguageModelSession(model:tools:instructions:)`,
`GenerationOptions(temperature:maximumResponseTokens:)`, and
`session.respond(to:options:) -> { content: String }` all compile as
documented, plus the full `LanguageModelSession.GenerationError` case set
(including one the docs didn't mention, `.unsupportedGuide`, added here as
a `decodingFailure` alias so the switch is exhaustive with no warnings).
`tool/swiftc_ai_gate.sh` now also typechecks this file and passes clean —
confirmed by actually running it in this session (this environment has the
iPhoneOS 26.5 SDK installed), not just trusting the script exists.

Deliberately asks the model for **plain text**, not a `@Generable` schema —
a single short line has nothing worth constraining beyond what the Dart
side already re-checks, so this avoids inventing a second schema next to
`ChallengeProposal`'s for the same "one line of text" concept.

Added `CommentaryProfile.swift` to `ios/Runner.xcodeproj/project.pbxproj`
(4 sections: PBXBuildFile, PBXFileReference, group children, Sources build
phase) and to `tool/swiftc_ai_gate.sh`'s `SRCS` list. Verified with a real
`flutter build ios --simulator --no-codesign` (not just the isolated
typecheck gate) — confirms the new file actually compiles as part of the
real app target, not just in the standalone gate script's own file list.

**Dart, new `lib/ai/commentary.dart`**: `CommentaryKind` (the 10 kinds from
[[AI Commentary]]), `isCommentaryLineValid` (a standalone text-only version
of `ChallengeValidator`'s ASCII/forbidden-token/meta-AI/length checks,
reusing its exported `kAsciiAllowlist`/`kForbiddenTokens`/`kMetaAiTokens`
constants rather than duplicating them), and `CommentaryProvider` — the
static-bank-first ladder: flag off / model unavailable / bridge failure /
invalid line / repeated line all fall back to the existing `Roasts` pools
[[AI Commentary]] already describes as the floor.

**Scope cut, logged deliberately:** five of the ten kinds
(`elimination`/`finalRound`/`winner`/`loser`/`closeMatch` — the
multiplayer-only ones) have no dedicated static pool of their own; authoring
real `roast.*`-style copy for them across all six locales is content work,
not a code change, so for now they map onto the tonally-closest existing
pool (`praise` or the mistake pool) as their static fallback. Not a
blocker — the AI path is still preferred when available; only the rare
"AI unavailable during a multiplayer match" fallback line is generic
rather than purpose-written.

**Not wired into the live game yet, on purpose.** `CommentaryProvider.line()`
is `async` (it awaits the bridge); `GameEngine.pass()`/`.fail()` must stay
synchronous (the game loop never awaits a model —
[[Performance and Resource Budgets]]). Wiring a real line into the
existing flash slots needs something to pop synchronously from an
already-filled cache — that's Phase 5's job, landing next.

New suite `test/ai/commentary_test.dart` — 14 cases: every
`isCommentaryLineValid` rejection rule, and the provider's full ladder
(flag off, unavailable, valid AI line used + remembered, invalid line
falls back, bridge failure falls back, a repeated line falls back instead
of showing twice, a caller-supplied fallback override).

**Verification:** `flutter analyze` clean; `flutter test` 252/252 (up from
238); `swift test` 61/61 unaffected (no package code touched);
`tool/swiftc_ai_gate.sh` passes against the real iPhoneOS 26.5 SDK; a real
`flutter build ios --simulator --no-codesign` succeeds with the new Swift
file compiled into the app target. Real generation still unverifiable
end-to-end (no Apple-Intelligence-capable device here) — same honest
caveat as every Phase 2 entry.

### 2026-09-11 — AI Director Phase 5: pre-generation cache, AI wired into production for the first time
Everything up to this point (Phases 1-2, A, B, 4) was infrastructure —
`FallbackChallengeProvider` in `game_screen.dart` was still constructed
with only `scripted:`, so the shipped game stayed 100% scripted regardless
of how much AI code existed. This phase changes that: `game_screen.dart`
now constructs a real `AIChallengeProvider` and passes it as `ai:`, and
also finally wires `AdaptiveChallengeProvider` (fully built since Phase 3
but never constructed in production) around the result.

**New `lib/ai/prefetch_loop.dart`**: `PrefetchLoop<T>` — the generic bounded
ring + single-in-flight background fetch primitive
([[Pre-generation Cache]]). Deliberately generic and not challenge-specific
(no `T` constraints), since the design doc describes two ring shapes off
the same primitive — a size-2 challenge ring and a size-1-per-kind
commentary ring — and only the challenge ring is actually consumed by
anything yet (see below).

**New `AIChallengeProvider` in `lib/ai/providers.dart`**: a `ChallengeProvider`
backed by one `PrefetchLoop`, `AppleAIService.requestChallenge`,
`ChallengeValidator`, and Phase A's `buildFromProposal`. **Self-sustaining
without new engine wiring**: `GameEngine._startLevel` calls
`ChallengeProvider.next()` exactly once per level with no separate
"prefetch ahead" event, so every `next()` call both pops whatever the ring
already has ready *and* kicks a fresh background fetch for the level just
started — good enough to usually have something ready by the next call,
without needing `GameEngine` to know AI exists at all. Cache key is
level-banded (`level ~/ 10`), not exact, so leveling up mid-band doesn't
thrash the fetch.

**A real bug found and fixed while writing `provider_test.dart`, not by
inspection:** the freshness/dedupe list (`_recentServed`, feeding
`ChallengeValidator`'s "not a near-duplicate of the last 4" check) was
updated inside the background fetch itself, before `PrefetchLoop` decided
whether to keep or discard the result. So a fetch that started, validated
successfully, and then got discarded as stale (because the cache key
changed while it was in flight — e.g. crossing a level band) still
permanently recorded its mechanic/decoy signature as "served," even though
the player never saw it. The very next legitimate fetch for that same
signature would then get wrongly rejected as a near-duplicate of a round
that was never shown to anyone. Caught by a test asserting a fresh fetch
after a level-band crossing should succeed — it returned `null` instead,
which traced back to this. Fixed by moving the dedupe bookkeeping out of
the fetch entirely and into `AIChallengeProvider.next()`, recorded only at
the moment an item is actually popped and handed to the engine (the cached
item now travels through `PrefetchLoop` paired with its
`ServedChallengeStamp` via a small private `_CachedChallenge` wrapper).
Added a dedicated regression test for exactly this scenario (two distinct
proposals, one legitimately served, one that becomes stale mid-flight) so
this can't silently regress.

**`AdaptiveChallengeProvider` wired into production, behind its own
default-off flag.** `game_screen.dart` calls
`adaptive.setProfile(telemetry.profile)` after `correct`/`wrong` events,
but only when `aiAdaptiveDifficultyEnabled` is true (default **off**) —
otherwise it keeps feeding `null`, which is `AdaptiveChallengeProvider`'s
documented cold-start-neutral state. So telemetry itself is always
collected (unchanged), but nothing about which challenge gets served
actually changes unless a player or QA explicitly opts in. One known
imprecision, judged not worth the complexity to fix: `game_screen.dart`
registers its own `_onGameEvent` listener on `GameEngine` in `initState()`,
before `TelemetryCollector` attaches its own listener later (in the
async `_setupTelemetry`) — since `GameEngine._emit` calls listeners in
registration order, `_syncAdaptiveProfile()` reads the profile one event
behind telemetry's own update for that same event. Negligible against a
50-round rolling window; not worth reordering async setup to fix.

**One shared `AiFeatureFlags.load()` for the whole screen.** `game_screen.dart`
starts the load once in `initState()` and shares the same `Future` between
`AIChallengeProvider`'s internal init and the screen's own adaptive-flag
gating — one `SharedPreferences` round trip, not two.

**Commentary caching deliberately not wired into `GameEngine` this phase.**
`PrefetchLoop` is fully generic and already *capable* of backing a
size-1-per-kind commentary ring exactly as [[Pre-generation Cache]]
describes, but there's no live consumer yet: `GameEngine.pass()` has no
generic "praise" slot to begin with (the correct-flash is only 240ms —
arguably too short to read a fresh line anyway), and `GameEngine.fail()`'s
existing `Roasts.forMistake(...)` fallback is the only real candidate slot,
which would need a small new override hook. Deferred to
[[Multiplayer AI Director]] (Phase 8), where the multiplayer-only kinds
(`elimination`/`finalRound`/`winner`/`loser`/`closeMatch`) actually need a
live wire consumer for the first time — building the hook once there,
for real usage, beats speculatively wiring `wrong` here first.

**Verification:** live-tested on the iOS Simulator (booted via `xcrun
simctl` directly, since the dedicated Simulator MCP tool's Xcode-selection
check failed despite `xcode-select -p` reporting Xcode correctly selected,
and interactive control of the Simulator app was declined when requested)
— confirmed the home screen renders correctly after the provider rewiring.
Full interactive play wasn't authorized, so relied on the existing
`test/app_flow_test.dart` widget suite instead, which already drives
`PLAY → level 1 → timeout → game over → retry`, tap-to-skip, and stats
recording through the real `GameScreen` — all now exercising the new
`AdaptiveChallengeProvider(FallbackChallengeProvider(scripted, ai:
AIChallengeProvider))` chain, and all green. `flutter analyze` clean;
`flutter test` 272/272 (up from 252 — 9 `PrefetchLoop` cases, 11
`AIChallengeProvider` cases, incl. the dedupe regression). Test file is
named `prefetch_loop_test.dart` rather than the `cache_test.dart` named in
the original phase plan — there's no separate "cache" class beyond
`PrefetchLoop` itself plus `AIChallengeProvider`'s own key/dedupe logic
(covered in `provider_test.dart`), so one file per real class felt more
honest than a `cache_test.dart` that would just re-test `PrefetchLoop`
under a different name.

### 2026-09-11 — AI Director Phase 6: `@Guide` schemas, real `requestChallenge`, three snapshot-backed tools
Closes the last real gap in the generation path: `requestChallenge` had
been stubbed with `notImplemented` since Phase 2, and the `@Generable`
proposal structs shipped in Phase 2 had zero `@Guide` annotations at all —
a real, flagged gap from that phase's own audit.

**`@Guide` annotations added across every `AYSChallengeProposal` field**
(`ChallengeProposal.swift`) — closed-vocabulary `.anyOf` for
`mechanic.move`/`.action`/`.kind`/`difficulty.trickType`/`AYSElement.color`/
`.shape`, `.range` for every numeric bound the Dart validator itself
enforces (`scale` 0.45-2.0, rotation/dx/dy ±0.6, opacity 0.35-1.0,
`timeLimitMs` capped at 8000, `level` 1-99), `.count(2...6)` on `elements`,
and `.pattern` (via `Regex(String)`, not a `/…/` literal — the literal
syntax doesn't parse inside a macro argument position, confirmed by
probe-compiling both forms against the real SDK) for the `id` format and a
"≤8 words, uppercase" approximation on `instruction`. **These guides steer
generation and reject some bad candidates outright, but are explicitly not
a substitute for `ChallengeValidator`** — several real rules (per-mechanic
time floors, decoy honesty, freshness against recently-served rounds,
tone, the mechanic/kind/trick cross-consistency contract) can't be
expressed as a single-field guide at all. Documented directly in the
struct's doc comment so a future reader doesn't assume more coverage than
these actually provide.

**Real `requestChallenge`**: new `ios/Runner/AppleAIService/ChallengeGenerationProfile.swift`,
same always-compiled-outer/`@available`-gated-inner split as
`AYSCommentaryService`. Two things worth logging:
1. **`@Generable` gives no `Encodable` conformance** — confirmed by
   probe-compiling `JSONEncoder().encode()` against a real
   `AYSChallengeProposal` and getting a type error. So the wire dict
   (`{id, mechanic, instruction, elements, correctAnswer, difficulty,
   failLine, seed, source}`, matching `ChallengeProposal.fromJson` exactly)
   is built by hand, field for field, in `wireDict(for:)`.
2. **A canonical English fail-line table** (`kCanonicalFailLines`, one line
   per of the 9 mechanics + a generic default) fills `failLine` — the
   dictionary field `@Generable` can't express, per the Phase 2 decision
   already on record. This is the "Swift provider injects fail lines from
   the mechanic's canonical fail lines at build time" follow-through that
   entry promised but didn't yet implement.

**Three `Tool` conformances, deliberately snapshot-backed, not a live
bridge.** New `ios/Runner/AppleAIService/GenerationTools.swift`:
`GetPlayerProfileTool`, `GetRecentChallengesTool`, `GetAvailableMechanicsTool`
— the three [[Dynamic Profiles and Tool Calling]] assigns to
`ChallengeGenerationProfile`. **Scope decision:** the design doc describes
tools that "call back into Dart via a tool bridge" for live game state — a
real bidirectional bridge (a Swift `Tool.call()` making a *reverse*
`FlutterMethodChannel` call into the running Dart engine mid-generation)
would be genuinely novel plumbing, unverifiable without a real device, and
unnecessary for this specific profile: `requestChallenge`'s existing
`profile` argument already carries everything these three tools need, sent
once, up front. So each tool here is backed by a snapshot Dart computed
*before* the session starts, not a live round trip — this still exercises
the real `Tool` protocol and constrained tool-calling behavior (the model
decides whether/when to call each tool during generation and gets a real
typed response), only the data source is pre-fetched. `GetCurrentScoresTool`
(multiplayer-only) and `ValidateChallengeTool` (would need a partial Swift
port of the Dart validator — the exact duplication this project has
deliberately avoided since the multiplayer judging-authority redesign)
are not implemented; `GetRoundHistoryTool` isn't actually assigned to any
profile in the source doc's own table, so it's skipped too.

**Dart side:**
- New `lib/ai/profile_for_prompts.dart`: `profileForPrompts(PlayerGameplayProfile?)`
  — the truncation facade [[Privacy and Offline]] requires (only
  `mostCommonMistakeCategory`, success rates rounded to the nearest 10%,
  `averageReactionTimeMs`, `fastestStreak`; cold start `null` still returns
  the same four keys with neutral defaults, so the Swift side never
  special-cases "no profile yet").
- New `availableMechanicMoves({required allowTricks})` in
  `challenge_vocabulary.dart`. **Real gap found while implementing this:**
  the design doc describes `GetAvailableMechanicsTool` as filtering by
  "mechanics whose `minLevel <= level`," but unlike the scripted
  `ChallengeTemplate` registry, `ChallengeMechanic` has no `minLevel` field
  at all — the AI vocabulary was never given per-mechanic level gating.
  Implemented what the data actually supports: filtering only on
  `requiresTrick`/`allowTricks`, the one real, well-defined gate. Noted
  inline rather than inventing a `minLevel` field with no source of truth
  behind it.
- `AIChallengeProvider` (`lib/ai/providers.dart`) now sends a real payload
  instead of just `{unitId, locale}`: `level`, `allowTricks`,
  `playerProfile` (via the facade above — fed by an optional
  `profileSnapshot` constructor callback, read fresh on every fetch since
  `game_screen.dart` constructs this provider before `TelemetryCollector`
  exists), `recentChallenges`, `availableMechanics`. One honest
  simplification: `recentChallenges` reuses each `ServedChallengeStamp`'s
  `mechanic` as both `challengeId` and `mechanic` in the payload, since
  AI-generated content stamps carry no stronger id
  (`ServedChallengeStamp` only ever tracked `{mechanic, decoySignature}`)
  — the tool's real purpose (avoid repeating a mechanic) only needs the
  mechanic anyway, so inventing a synthetic id would add nothing.
- `game_screen.dart`: passes `profileSnapshot: () => _telemetry?.profile`.
  Deliberately **independent of `aiAdaptiveDifficultyEnabled`** — that flag
  only gates `AdaptiveChallengeProvider`'s deterministic re-weighting of
  already-validated candidates; letting the model *see* a truncated
  profile during generation is a different mechanism, already covered by
  `aiChallengeGenerationEnabled` alone, and [[Privacy and Offline]]'s
  allowed-prompt-content table doesn't gate it behind adaptive difficulty
  either.

New tests: `test/ai/profile_for_prompts_test.dart` (5 cases: cold-start
defaults, 10%-rounding, and that only the four allowed keys are ever
present), plus a new `provider_test.dart` case asserting the actual
`requestChallenge` payload carries `level`/`allowTricks`/`playerProfile`/
`recentChallenges`/`availableMechanics`, not just `locale`.

**Verification:** `flutter analyze` clean; `flutter test` 278/278 (up from
272); `tool/swiftc_ai_gate.sh` passes against the real iPhoneOS 26.5 SDK
with all 5 AI Swift files now typechecked together; a real `flutter build
ios --simulator --no-codesign` succeeds with the new tool/generation-profile
Swift files compiled into the app target (added to
`ios/Runner.xcodeproj/project.pbxproj` the same 4-section way
`CommentaryProfile.swift` was in Phase 4). Real generation still
unverifiable end-to-end — no Apple-Intelligence-capable device in this
environment, same standing caveat as every phase since 2.

### 2026-09-11 — AI Director Phase 7: the six multiplayer wire messages, on both ends
Six new additive `PartyMessage` kinds for [[Multiplayer AI Director]], on
both `lib/multiplayer/protocol/protocol.dart` and
`tvos/Sources/AYSProtocol/ProtocolModel.swift`: `AI_CAPABILITIES` (client →
host), `AI_DIRECTOR_ASSIGNMENT` (host → all), `AI_ROUND_PROPOSAL` (client →
host, Director only), `AI_CHALLENGE_ROUND` (host → all), `AI_COMMENTARY_PROPOSAL`
(client → host, Director only), `AI_COMMENTARY` (host → all). Naming
follows this protocol's real convention (flat Upper-`SNAKE_CASE`, no
direction prefix) rather than the design doc's `client/aiCapabilities`
sketch, and there are six kinds rather than the doc's four — its table
conflates "the Director produces X" and "the host relays X" into one row,
but those are necessarily distinct wire messages here (client→host vs.
host→all), a discrepancy flagged back when the AI Director work was first
scoped this session. `proposal` stays an opaque `Map<String, Object?>` /
`[String: Any]` on both sides — neither protocol file gains a dependency
on `ChallengeProposal`'s actual shape, mirroring how `RoundStart.config`
already stays opaque.

**Golden fixtures regenerated** (`dart run tool/gen_protocol_fixtures.dart`,
26 → 34 lines) and `ProtocolTests.swift` extended with 6 new
`testAiXMatchesGolden`-style assertions plus the updated line-count
tripwire — the exact 5-step contract this codebase already established for
adding a message kind, followed verbatim.

**`party_session.dart` (client) dispatch, plumbing only:** the three
host→all kinds get `PartyEvent` subclasses
(`PartyDirectorAssignedEvent`/`PartyAiChallengeRoundEvent`/
`PartyAiCommentaryEvent`) and two new `PartyState` fields
(`aiDirectorPeerId`, `lastAiCommentary`) — `AiChallengeRound` deliberately
does **not** open a round yet (`state.round` stays untouched); actually
consuming it to start a round via `generated_challenge_runtime.dart` is
Phase 8's job, once a Director exists to have sent one for real. Three
thin outbound methods (`sendAiCapabilities`/`sendAiRoundProposal`/
`sendAiCommentaryProposal`) exist now so Phase 8's `PartyAiDirector` has
something to call — deciding *when* to call them is explicitly not this
phase's concern.

**`RoomHost.swift` (host) dispatch, plumbing only:** a new `Seat.aiCapabilities`
field + `onAiCapabilities` handler remembers each seat's announced
capability (read by nothing yet — the election is Phase 8) and a public
`aiCapabilities(for:)` accessor for that. `AI_ROUND_PROPOSAL`/
`AI_COMMENTARY_PROPOSAL` get an explicit accept-but-no-op case in `handle()`
— **without this, they'd fall into the existing `default:` branch and get
answered with a `BAD_MESSAGE` error**, since that branch is for
*known-but-wrong-direction* messages (e.g. a client somehow sending
`HOST_HELLO`), not for *known-but-not-yet-acted-on* additive kinds. A v1
phone sending these ahead of Phase 8 isn't misbehaving, so erroring would
have been wrong.

New tests: Swift `AIDirectorTests.swift` (4 cases — capability remembered
per seat, an un-announced seat has none, both Director-only proposal kinds
accepted without a `BAD_MESSAGE`), Dart `party_session_ai_test.dart` (5
cases — the two state-updating broadcasts, the round-opening event firing
without touching `state.round`, and all three outbound sends actually
reaching the wire). One test-writing mistake worth noting: the first draft
delivered synthetic host→client messages via `InMemoryPartyTransport.deliver()`
directly on the wrong end of the pair (`hostSide.deliver(...)` adds to
`hostSide`'s *own* inbound, not the peer's) — caught immediately by every
assertion coming back `null`; the fix is `hostSide.send(...)`, which
correctly routes through `_peer!.deliver(...)` to the client's inbound.

**Verification:** `flutter analyze` clean; `flutter test` 283/283 (up from
278); `swift test` 71/71 (up from 67, package tests only — no
`AYS_RUN_NETWORK_TESTS` needed for this phase). No behavior change for any
existing message kind; every new kind is additive and forward-tolerant
(an old peer that doesn't know about them silently ignores them, per the
protocol's existing contract).

### 2026-09-11 — AI Director Phase 8: election, relay, failover, and the Director runtime itself
The phase that makes the whole multiplayer AI Director feature *functional*
end-to-end rather than plumbing waiting for a consumer. Every piece from
Phases A–7 gets a real caller for the first time in a multiplayer match.

**`RoomHost.swift` — election, a single-slot proposal queue, relay, failover:**
- `electDirector()` picks the highest `computeRank` among seats that sent
  `AI_CAPABILITIES` with `aiAvailable: true`, tie-broken by the
  lexicographically smaller `playerId` (decision #5 from this feature's
  original scoping: a single compute-rank tier, no battery-based tie-break,
  to avoid a new device-info dependency for something unverifiable without
  real hardware anyway). Runs once at `startGame()`, and again whenever the
  elected Director's seat is actually *removed* (`removeSeat`) — not on a
  mere disconnect still inside the reconnect grace window, so a Director
  that reconnects in time keeps its assignment instead of losing and
  immediately regaining it. Only broadcasts `AI_DIRECTOR_ASSIGNMENT` when
  the winner actually changes.
- `pendingAiProposal`, a **single slot, not a queue** — mirrors
  [[Pre-generation Cache]]'s "the host never waits" contract from the other
  side: `AI_ROUND_PROPOSAL` from the elected Director (anyone else's is
  silently ignored — the trust boundary the election exists to establish)
  fills it; `startNextRound(level:)` — the new production entry point
  `HostViewModel` now calls instead of `startRandomRound` directly —
  consumes it if present, otherwise falls back to the scripted picker,
  exactly like a cache underflow. `AI_COMMENTARY_PROPOSAL` isn't queued at
  all (relayed as `AI_COMMENTARY` immediately) since there's no "next round"
  moment to wait for.
- `startAiRound(proposal:level:)` opens a round from a relayed proposal
  **without re-validating it** — no `ChallengeValidator`/registry on this
  side, so this trusts the Director exactly the way it already trusts every
  player's self-reported `PlayerAction.correct`. Broadcasts
  `AI_CHALLENGE_ROUND` instead of `ROUND_START`; `RoundCountdown`
  READY/GO follow identically. `ChallengeSpec.challengeId`/`.seed` are
  placeholders (`"ai"`/`0`) since nothing downstream reads them for an AI
  round — only `.durationMs` (read from `proposal.difficulty.timeLimitMs`)
  matters, for the force-timeout deadline `completeRound()` already had.

**`party_session.dart`/`party_state.dart` (client) — actually opening the round:**
`buildPartyChallengeFromAiRound` (new, `party_state.dart`) parses the
relayed proposal and calls Phase A's `buildFromProposal` — every phone
interprets the *same* relayed content instead of replaying a seed, since
an AI proposal has no shared generator to rebuild from. Deliberately
catches **any** exception, not just `FormatException`:
`ChallengeProposal.fromJson`'s nested `MechanicRef`/`CorrectAnswer`/
`DifficultySpec` parsers throw a plain `TypeError` (not `FormatException`)
on a missing required field (`json['move'] as String` on `null`), and this
path has to survive any shape of malformed content from an untrusted relay
— the host doesn't validate what it forwards. On a parse failure: a
`PartyError(code: 'BAD_AI_PROPOSAL')` surfaces locally and `state.round`
stays untouched, rather than crashing. `RoundCountdown`/the runner-start
path needed **no changes at all** — both already key off `round.id` alone,
content-agnostically, so they work transparently for an AI round the
moment `state.round` is set.

**New `lib/multiplayer/ai/party_ai_director.dart` — the elected phone's loop.**
Every connected phone constructs one (inert until named Director), reusing
the exact single-player building blocks — `AppleAIService`,
`ChallengeValidator`, `buildFromProposal`'s proposal pipeline — but pushing
results over the wire (`sendAiRoundProposal`/`sendAiCommentaryProposal`)
instead of into a local `PrefetchLoop` ring: the host's own single-slot
`pendingAiProposal` *is* the cache, so this class only ever keeps one round
generation in flight, mirroring `RoomHost`'s "never wait" contract from the
sending side. Announces capabilities once (`PartyJoinedEvent`); generates
ahead of need on every round-open event (scripted or AI, so the *next*
round has time to arrive); sends commentary on `PlayerEliminated` and
`GameEnd` (`winner`/`loser` by whether `end.winnerId` is this phone's own
`selfClientId`). A caught mistake while writing it: the `CommentaryProvider`
field initially needed a real `AiFeatureFlags` synchronously in the
constructor's initializer list, but flags load asynchronously — an early
draft plugged in a `noSuchMethod`-throwing placeholder "for now," which
would have crashed the very first commentary attempt after flags actually
resolved (the placeholder object, not the resolved flags, was what
`CommentaryProvider` had captured). Fixed by making the field nullable and
only constructing the real `CommentaryProvider` once `_initFlags` resolves
— the same "cold start returns null/no-ops" contract every other
async-flag-gated class in `lib/ai/` already follows.

**Wired into production:** `mp_join_screen.dart` constructs a
`PartyAiDirector` alongside every `PartySession`, using the same
`AppleAiMethodChannel`/`AiFeatureFlags.load` pattern `game_screen.dart`
established in Phase 5. Its disposal is intentionally asymmetric with
`_session`'s own well-established pattern: cancelled here only when the
player abandons the join flow before navigating away (mirroring
`_session?.dispose()`'s own `if (!_navigated)` guard) — once navigated, it
rides along with the session's real lifetime (threaded through
Lobby/Game/Result screens) rather than needing a new parameter threaded
through three more files; the underlying broadcast stream closing when
`_session` is eventually disposed completes its subscription on its own.
`HostViewModel.swift`'s `startGame()`/`nextRound()` now call
`startNextRound` instead of `startRandomRound` directly — the one-line
change that actually makes an AI-generated round reachable in a live
match. A small "AI: `<name>`" label was added to `RoundView.swift` (not
`LobbyView.swift` as originally planned in this feature's scoping) —
election runs at `startGame()`, not while still in the Lobby, so a Lobby
label would always read empty; showing it during the round, where
`directorName` is actually populated, was the only place it could mean
anything.

**Scope cuts, deliberate:** commentary lines aren't displayed anywhere in
the UI yet — `HostViewModel.lastAiCommentary` is captured but unconsumed,
same as single-player's Phase 5 deferral of its own commentary cache for
the identical reason (no natural existing slot, real UI design work,
better done as its own targeted pass than bolted on here). `sendAiRoundProposal`'s
`roundId` argument is a Director-side-only bookkeeping value — the host
mints its own real round id in `startAiRound` and never reads the one the
Director sent.

New tests: Swift `AIDirectorTests.swift` extended from 4 to 16 cases
(election picks highest rank / tie-breaks on `playerId` / no capable seat
→ no Director; `startNextRound` uses a pending proposal or falls back to
scripted; a proposal is consumed exactly once; an impersonated
round/commentary proposal from a non-Director is ignored; the Director's
own commentary is relayed to everyone; failover on the Director's seat
actually being removed, both with and without another candidate; a
pre-game leave excludes that seat from the election). Dart
`party_ai_director_test.dart` (10 cases, new) using a small purpose-built
harness (`InMemoryPartyTransport.pair()` + a `MockAppleAIService`)
covering the same ground from the Director's own sending side.
`party_session_ai_test.dart` extended — the two `AI_CHALLENGE_ROUND` cases
rewritten from "Phase 8 wires the round itself" to actually assert a real
round opens (or a `PartyError` surfaces on malformed content).

**Verification:** `flutter analyze` clean; `flutter test` 294/294 (up from
283 — 10 new `PartyAiDirector` cases, `party_session_ai_test.dart`'s two
rewritten cases net the same count); `swift test` 83/83 (up from 71 — 12
new `AIDirectorTests` cases); both `AYSHost-tvOS` and `AYSHost-macOS`
Xcode targets build clean with the `HostViewModel`/`RoundView` changes; a
real `flutter build ios --simulator --no-codesign` succeeds with
`party_ai_director.dart` wired into production. Real multi-device,
real-model verification remains out of reach in this environment (no
Apple-Intelligence-capable hardware, and interactive Simulator control was
declined when requested in an earlier phase) — the entire pipeline is
proven correct by construction (unit + integration tests on both language
sides) and by successful compilation into both real app targets, not by
an actual live match.

**Two real bugs found immediately after, while reviewing this same class
before moving on — not by a user report:**
1. `_maybeSendCommentary` had **no `_isDirector` check at all.** Every
   connected phone (not just the elected Director) would independently try
   to generate and send a commentary proposal on the same
   `PlayerEliminated`/`GameEnd` event — the host's `onAiCommentaryProposal`
   already only accepts the actual Director's proposal, so the wrong
   phones' attempts were silently dropped, but every non-Director phone
   was still wastefully calling the model for nothing. Fixed by adding the
   same `_isDirector` guard `_maybeGenerateRound` already had — the
   asymmetry between the two methods is what surfaced it on a second read.
2. **`aiMultiplayerDirectorEnabled` was defined in `AiFeatureFlags`
   (Phase B) but never actually read anywhere** — `PartyAiDirector` gated
   round generation on `aiChallengeGenerationEnabled` and commentary on
   `aiCommentaryEnabled`, but nothing gated *being a Director candidate at
   all* on the one flag whose entire purpose is exactly that. Fixed by
   gating `_announceCapabilities` (announces `aiAvailable: false`
   regardless of the real device state when the flag is off, so this
   phone can never be elected) and, as defense in depth, `_maybeGenerateRound`/
   `_maybeSendCommentary` too. Surfaced while writing this entry and
   double-checking every flag actually has a real reader — worth doing
   for any flag introduced ahead of its consumers, as this one was.

Also fixed while wiring the gate: `_announceCapabilities` originally read
the nullable `_flags` field, racing against `_initFlags`'s async load —
since it only ever fires once (on `PartyJoinedEvent`, early in the
connection lifecycle), losing that race would have meant never announcing
capabilities at all for the rest of the session. Fixed by storing the
`Future<AiFeatureFlags>` itself (not just the eventually-resolved value)
and `await`ing it directly — safe and cheap even after it's already
completed, and immune to ordering.

Three new regression tests (`party_ai_director_test.dart`): a non-Director
phone never sends commentary on the same event a Director would; the flag
being off forces `aiAvailable: false` in the capability announcement
regardless of real device availability; the flag being off blocks
generation even for a phone somehow already named Director. `flutter test`
297/297 (up from 294).

### 2026-09-11 — AI Director Phase 9: the Settings Ai section
The data module (`AiFeatureFlags`) has been real since Phase B; this phase
is purely the UI on top of it — a mode picker (`Genius`/`Focused`/`Classic`)
plus the per-device availability copy [[Error States and Failure
Communication]] specifies.

**New `_AiSection`** in `settings_screen.dart`, following the exact
`_LanguageRow`/dialog-picker pattern the language setting already
established. Deliberately self-contained rather than threaded through
`AppServices`: `AiFeatureFlags` isn't a `ChangeNotifier` (nothing in
`lib/ai/` needs to *react* to a flag change — every consumer just reads it
fresh next time), so this widget loads its own copy in `initState` and
manages its own `setState` reactivity, the same separation
`_RemoveAdsSection` already uses for its own `PurchaseManager` listener.
The picker is disabled only when the device genuinely can't run the model
at all (`deviceNotEligible`/`unsupportedOS`/`bridgeUnavailable`) —
`appleIntelligenceNotEnabled`/`modelNotReady` keep it interactive, matching
the doc's "Picker stays visible/interactable" note for the not-yet-enabled
case specifically.

**A real test-authoring discovery, not an app bug:** `test/localization_test.dart`
enforces exact key-set parity across all six locale files — the English
fallback `Strings.t` documents is a *runtime* safety net for a
half-translated key, not license to skip translating a new one. An early
draft added the new `ui.settings.ai.*` keys to `strings_en.dart` only
(reasoning that "AI content stays English-only" also applied to this UI
chrome); the parity test caught it immediately. Added real translations
(IT/FR/ES/PT/DE) for all 8 new keys instead — short UI labels and one
status sentence per state, well within reach for a straight translation
pass, unlike full game-content authoring.

**A second, more interesting test-authoring discovery, this time a real
Flutter-test-framework gotcha:** the widget test for this section
(`app_flow_test.dart`) hung indefinitely the first several attempts.
`_AiSection._load()` calls the real `ays/apple_intelligence` MethodChannel
(`AppleAiMethodChannel().available()`) with **no mock handler installed**
— and in a `testWidgets` binding, an entirely unregistered `MethodChannel`
call just never resolves, rather than rejecting with
`MissingPluginException` the way `apple_ai_service_test.dart`'s equivalent
"no native handler" case does in a bare `test()`. Adding more `tester.pump()`
calls didn't help (confirmed by explicit debug prints: `available()`
genuinely never returned, no exception ever fired). Fixed by installing an
explicit mock handler
(`TestDefaultBinaryMessengerBinding...setMockMethodCallHandler`) answering
`available` with an `unavailable`/`bridgeUnavailable` response, matching
what a real environment without the model would actually return. Worth
remembering for any future widget test that exercises AI-bridge-backed UI:
a bare `testWidgets` needs an explicit channel mock even where a
same-purpose bare `test()` doesn't.

**Verification:** `flutter analyze` clean; `flutter test` 298/298 (up from
297 — the new `app_flow_test.dart` case); a real `flutter build ios
--simulator --no-codesign` succeeds with the Settings UI changes compiled
in. Not visually confirmed on a live simulator screen (interactive
Simulator control remains declined from an earlier phase) — verified by
the widget test's exact text assertions instead.

### 2026-09-15 — AI Director Phase 10: a real gap found writing the first full-run test
Every prior phase's tests exercise one layer in isolation (`AIChallengeProvider`
at a fixed `ChallengeContext`, a single `GeneratedChallengeRuntime`
instance, a single `PartyAiDirector` event). Nothing had ever driven the
*exact* production composition `game_screen.dart` builds
(`AdaptiveChallengeProvider` → `FallbackChallengeProvider` →
`ScriptedChallengeProvider` + `AIChallengeProvider`) through a real,
multi-round `GameEngine` run — the "full match with mock bridge" item
[[Development Plan]] Phase 10 called for. New
`test/ai/full_run_with_mock_bridge_test.dart`.

**Real product bug found, not just a test gap:** `AIChallengeProvider.next()`
had no check against `Difficulty.isStarter(level)` at all. The scripted
registry enforces CLAUDE.md's "levels 1-3 stay trivial (starter: true
templates only)" pillar itself, via `ChallengeGenerator`'s own `starter`
filter — but `AIChallengeProvider` sits *in front of* that registry in
`FallbackChallengeProvider`, and a `ChallengeProposal` has no `starter`
flag for anything to filter on. Before this fix, a model-generated
non-trivial challenge could have been served as early as level 1. Fixed
with an explicit `if (Difficulty.isStarter(context.level)) return null;`
in `AIChallengeProvider.next()` ([lib/ai/providers.dart](../../lib/ai/providers.dart)),
plus a regression group in `provider_test.dart` covering levels 1-3
(never touches the bridge) and level 4 (eligible). `_context`'s level in
that file moved from 1 to 5 — same cache-key band (`level ~/ 10`), so
every pre-existing assertion in that file keeps meaning exactly what it
did before — to stop colliding with the new starter-gate tests without
touching them.

**Design choice, not a bug:** the new full-run test drives real
`Challenge`/`GameEngine` objects directly (tap the winning target,
tick past flashes) rather than `testWidgets` taps on rendered pixels.
Level 4+ can hand back *any* of the ~39 registered templates (the starter
gate only *restricts to* starters below level 4, it doesn't *exclude* them
above it), and which one the RNG picks is unpredictable — a generic
"find the right button for any rendered template" driver would be a much
bigger, more brittle undertaking than this test needs (every template
already gets its own exhaustive coverage in `challenge_behaviour_test.dart`
/ `challenge_templates_test.dart`). So the test's own `ChallengeGenerator`
is constructed with only the 4 `starter: true` templates
(`kChallengeTemplates.where((t) => t.starter)`) — the scripted floor is
narrowed, but the real `AIChallengeProvider`, `PrefetchLoop`,
`ChallengeValidator` and `AdaptiveChallengeProvider` under test are not.
The 4 starters split cleanly into two answerable shapes: `TapTargetChallenge`
subclasses (`tap_color`, `tap_number`, `dont_tap_color` — the winning id(s)
are the public `correctIds` field) and `ExactTapsChallenge` (`tap_twice` —
two taps on `'pad'`); an AI-sourced round answers on
`proposal.correctAnswer.elementId`. Three answerable shapes, one small
`switch`-shaped driver, no rendering coupling.

**A second real gotcha, this time in the test's own mocked proposals, not
production code:** the first draft of the test used descriptive ids like
`ai.round-1` for each mocked `ChallengeProposal`. `ChallengeValidator`'s
envelope check requires `id` to match `^ai\.[a-z0-9]{5}$` — no hyphens,
exactly 5 lowercase-alphanumeric characters — so every one of those ids
was silently rejected as `VerdictInvalid('envelope.id')`, and the AI path
never served a single round across the whole test, with no clue why
beyond "requestChallenge keeps getting called and nothing ever pops."
Found by writing a scratch diagnostic that called `ChallengeValidator`
directly on the exact same mocked proposal and printed the verdict's
`reason` — the fastest way to distinguish "the async plumbing is wrong"
from "the payload itself is rejected" when a `PrefetchLoop`'s pop
silently stays empty. Fixed by using valid 5-character ids
(`ai.aaaa1`, `ai.bbbb1`, …) throughout.

**Verification:** `flutter analyze` clean; `flutter test` 303/303 (up from
298 — the 4 new starter-gate cases in `provider_test.dart` plus 1 new
full-run test). `docs/Home.md` and `docs/AI/Development Plan.md` updated;
[[Testing and Evaluation]]'s blind-playtest and real-device gates remain
explicitly unexercised (no Apple-Intelligence hardware in this
environment) — the honest caveat every phase since Phase 2 has carried.
