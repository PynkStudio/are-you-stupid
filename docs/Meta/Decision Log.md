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
