---
tags: [development, release]
updated: 2026-10-17
---

# Release Checklist

Current production submission: **1.0.0**. Current release candidate:
**1.2.0 (8)**, adding the native Stupid Streak extension and multiplayer
presenter/name-intelligence work described in [[iMessage Multiplayer]] and
[[Multiplayer Presenter]]. One App Store record ships three platforms (universal
purchase, bundle id `com.ays.areYouStupid`): the Flutter phone app (iPhone +
iPad), the Apple TV host and the Mac board host (`tvos/`, see
[[Multiplayer Host (tvOS)]]). Google Play ships the Android phone app
(`com.ays.are_you_stupid`). The two ids differ in casing and stay that way:
a store id can never change after the first upload, and the AdMob apps are
already registered against them ([[Decision Log]]).

## Code

- [x] `flutter analyze` — zero issues (2026-10-02)
- [x] `flutter test` green — 303/303 (2026-10-02, after the audit fixes)
- [x] `swift test` (from `tvos/`) green; `AYSHost-macOS` and `AYSHost-tvOS`
      Release builds succeed with the new store config (2026-10-02)
- [x] `docs/` updated ([[Documentation Rules]])
- [x] Presenter: `tvos/Config/Presenter.secrets.xcconfig` present on the
      build machine (token = Vercel `AYS_PRESENTER_API_TOKEN`); run
      `scripts/fetch_presenter_pack.sh` then `xcodegen generate` (from
      `tvos/`) so the release bundles the latest published pack
      ([[Multiplayer Presenter]]). Completed 2026-10-11: revision 1 for all
      six locales, 66 SHA-verified clips bundled.
- [x] Build number bump automated — `scripts/bump_build_number.sh`, wired
      into the iOS Archive pre-action and the Android `assembleRelease`/
      `bundleRelease` Gradle tasks ([[Getting Started]])

## Compliance (fixed in the 2026-10-02 audit)

- [x] **GDPR consent** — UMP form before any ad request, then ATT, then the
      SDK; "AD PRIVACY CHOICES" row in Settings when UMP requires it
      ([[Monetization and Ads]])
- [x] **ATT** requested only once the app is active (post-frame of
      `HomeScreen`), never during the splash
- [x] **Restore purchases** always visible; product re-queried when
      Settings opens
- [x] iPhone portrait-only in `Info.plist`; iPad `UIRequiresFullScreen` +
      portrait (portrait lock is ignored on iPad otherwise)
- [x] `CFBundleLocalizations` + localized permission prompts in six
      languages ([[Localization]])
- [x] Android camera declared optional (`uses-feature required="false"`)
- [x] AI off on Android ([[Feature Flags]])
- [x] Export compliance: `ITSAppUsesNonExemptEncryption = false` in the
      phone and host `Info.plist`s
- [x] Mac App Sandbox entitlements + macOS app icon for the board host
- [x] The icon artwork reads "ARE YOU STUPID?!": `icon_source.png` is the
      original art (only "?"); `python3 tool/add_icon_bang.py` writes
      `icon.png` with the matching "!". Then run `dart run
      flutter_launcher_icons` (Android + iOS) **before**
      `python3 tool/make_apple_icons.py` (it must run last for iOS/macOS) and
      `python3 tool/make_tv_icons.py`
- [x] One full-bleed `icon.png` master generates the iPhone/iPad catalog and
      both macOS catalogs via `python3 tool/make_apple_icons.py`; iOS has no
      pre-baked mask or pale corners, while Mac uses a transparent rounded tile
      with no light rim (macOS ≤ 15) plus the Icon Composer
      `macos/Runner/AppIcon.icon` that macOS 26+ masks itself
- [x] Android release signs with the real upload key (`android/key.properties`
      + `upload-keystore.jks`, both gitignored — back them up offline)

## AdMob console (not code)

- [ ] *Privacy & messaging* → create and **publish** a GDPR message for both
      apps (the UMP form shows nothing until one is published), optionally
      an IDFA explainer for iOS
- [ ] Link each AdMob app to its store listing once live
- [ ] `app-ads.txt` on `pynkstudio.eu` (root) with the publisher line from
      AdMob → *Apps* → *app-ads.txt*; set `pynkstudio.eu` as the developer
      website in both stores

## App Store Connect

- [ ] Apple Developer Program active; distribution certificate available
      (automatic signing, team `G48384PHQK`)
- [x] One app record (Apple ID 6809188487, "ARE YOU STUPID?! - party
      game"), bundle id `com.ays.areYouStupid`, with **iOS, tvOS and macOS**
      platforms; subtitle, categories (Games › Word, Casual + Entertainment),
      free in 174 regions (Mainland China excluded: games there need a
      government licence), Game Center off (2026-10-02)
- [x] Three non-consumable in-app purchases (`ays_remove_ads`,
      `ays_party_pack`, `ays_party_bundle`) created, priced and localized;
      review notes and the reviewer screenshot are uploaded and all three are
      attached to the first iOS review submission.
- [x] App Privacy published 2026-10-02: **Data used to track you** — Device ID (IDFA),
      Advertising Data, Product Interaction, Coarse Location, Diagnostics
      (all from the Google Mobile Ads SDK). *Not* "no data collected"
- [x] Privacy Policy URL `https://pynkstudio.eu/it/lavori/are-you-stupid/privacy`;
      Support/Marketing URL the `/en` game page. The Apple TV-specific privacy
      disclosure states that the host exchanges only ephemeral local-network
      game data and has no ads, analytics, accounts or purchases.
- [x] Age rating questionnaire: frequent profanity/crude humor, ads →
      **13+** (12+ in Vietnam/Korea)
- [x] Description, promo text, keywords, support/marketing URLs, review notes
      and reviewer contact details are filled for iOS, tvOS and macOS.
- [x] Review notes: multiplayer needs the Apple TV / Mac host on the same
      Wi-Fi; Apple Intelligence features need an iOS 26 eligible device and
      fall back to scripted challenges otherwise
- [x] English master screenshot campaign generated in `store_assets/output/`
      from real in-app captures: iPhone 6.9" (1320×2868), iPad 13"
      (2064×2752), Apple TV (3840×2160) and Mac (2880×1800). The repeatable
      composer is `store_assets/generate_store_screenshots.py`; outputs are
      RGB PNGs without alpha. iPad artwork presents the phone controller
      capture inside the campaign layout rather than pretending it is a
      native iPad capture. The same script also writes the Google Play set:
      `play-phone/` (five 1080×1920 shots — Play rejects anything taller
      than 2:1, so the 6.9" iPhone files can't be reused) and
      `play-feature/` (1024×500 feature graphic, 512×512 icon).
- [x] Replacement six-panel editorial carousel generated for iPhone 6.9-inch
      and iPad 13-inch in `iphone-6.9-carousel/` and `ipad-13-carousel/`.
      Each panel combines real UI detail with a product benefit; iPad uses
      edge-to-edge editorial crops rather than an iPhone device frame. The
      replacement sets require visual approval before the live iOS submission
      is withdrawn and updated.
- [x] Five-panel iMessage/Stupid Streak carousel generated at 1320×2868 in
      `store_assets/output/imessage-6.9-carousel/`, covering start, play,
      hidden-score waiting, round result and rematch. It requires visual
      approval and upload with the replacement iOS metadata.
- [x] Screenshot sets uploaded to App Store Connect: five iPhone 6.9-inch,
      five iPad 13-inch, three Apple TV and three Mac images (2026-10-03)
- [x] Build `1.0.0 (4)` selected and saved for iOS, macOS and tvOS
      (2026-10-03)
- [x] Content-rights declaration completed: the app may display authorized
      third-party content through its advertising integration.
- [x] iOS 1.0 plus all three in-app purchases, macOS 1.0 and tvOS 1.0 sent to
      App Review on 2026-10-03; all three submissions show **Waiting for
      Review**. Automatic release after approval remains selected.
- [x] iOS `1.1.0 (5)` delivered to App Store Connect/TestFlight with
      Transporter at 19:02 on 2026-10-03; Apple processing is still in
      progress. The two-device Stupid Streak delivery gate remains required
      before promoting it beyond testers.

## Google Play Console

Developer account **PynkStudio** (id `8227410769086375104`) is a **personal**
account. Google requires personal accounts created after November 2023 to run
a **closed test with at least 12 opted-in testers for 14 consecutive days**
before production access can be requested — production cannot be the first
track ([[Decision Log]]).

- [x] App created 2026-10-06 (app id `4973937346472521775`): "ARE YOU
      STUPID?! - party game", package `com.ays.are_you_stupid`, Game, free,
      default language en-US, Play App Signing terms accepted, automatic
      protection on
- [x] Privacy policy: `https://pynkstudio.eu/it/lavori/are-you-stupid/privacy`
- [x] Ads: yes. Advertising ID: yes (AdMob merges
      `com.google.android.gms.permission.AD_ID`) — analytics, advertising,
      fraud prevention
- [x] Sign-in details: no account; reviewer notes explain the optional
      purchases and that party mode needs the Apple TV/Mac host on the same
      Wi-Fi
- [x] Content rating (IARC): mild crude language + moderate profanity
      (frequent), digital purchases, users interact (player names on the
      local board, invited players only). Australia: PG
- [x] Target audience: **16–17 and 18+** (not 13+: a 13–15 band puts the
      app under the Families ad requirements — [[Decision Log]])
- [x] Data safety: approximate location, app interactions, crash logs,
      diagnostics, device or other IDs — collected *and* shared (Google
      Mobile Ads SDK), not ephemeral, required; purposes analytics,
      advertising/marketing, fraud prevention; encrypted in transit; no
      account creation
- [x] Government / financial / health declarations: none
- [x] Store settings: category Casual, contact `android@pynkstudio.eu`,
      website `https://pynkstudio.eu`
- [x] Default store listing (en-US): short + full description, 512 icon
      (declared as AI-generated), feature graphic 1024×500, five 1080×1920
      phone screenshots from `store_assets/output/play-*`
- [x] Internal testing track: tester list "PynkStudio testers"
- [ ] Upload `build/app/outputs/bundle/release/app-release.aab` to the
      internal testing release and roll it out (drag the file in by hand:
      the browser automation can't push a 66 MB file)
- [ ] Google Payments merchant account (Monetize → Products shows
      "Configura un account commerciante"; business, tax and bank details —
      account holder only)
- [ ] One-time products `ays_remove_ads` €2.99, `ays_party_pack` €4.99,
      `ays_party_bundle` €5.99 (Monetize → Products; needs the merchant
      account *and* an uploaded build with the BILLING permission)
- [x] 2026-10-12: closed testing track **Alpha** set up — release
      **1.2.0 (code 9)**, all countries, testers via Google Group
      `ays-beta-testers@googlegroups.com` (invite-only for now; the
      pynkstudio.eu beta manager collects Gmail addresses), feedback to
      `android@pynkstudio.eu`, opt-in link
      `https://play.google.com/apps/testing/com.ays.are_you_stupid`.
      Sent to Google for the first review together with the store listing
      and app-content declarations.
- [x] 2026-10-17: Android **1.2.0 code 13**, release name
      `13 (1.2.0) — Skia compatibility`, uploaded to closed-test Alpha and
      submitted to Google review for a 100% rollout. Managed publishing is
      off, so approval distributes it automatically. The signed AAB is
      `build/app/outputs/bundle/release/app-release.aab` (SHA-256
      `3ddb0c0d5defda97ade1e1bd32cbfd7ed7120af08b35f0896f46087331d13f13`).
      Next gate: confirm first launch on the Moto G84 5G XT2347-2 (Android
      15) that exited during the native launch screen on code 9. Keep Android
      Impeller disabled until that pass or a conclusive native crash trace;
      see [[Decision Log]].
- [x] 2026-10-17: code 13 was approved and published to Alpha the same day.
      Android **1.2.0 code 14** (release name `14 (1.2.0)`, AAB SHA-256
      `6ec50b5c…b38889`) uploaded to closed-test Alpha and sent to Google
      review; code 13 is replaced by it. No supported devices lost.
- [x] Form factors: phones only. Google Play Games on PC removed; Android XR
      can't be switched off (it shares the phone track) ([[Decision Log]])
- [ ] Closed testing track with ≥ 12 testers, opted in for 14 days
- [ ] Apply for production access, then submit the production release
- [ ] Optional: localized listings for the other five app languages

## Builds

```bash
flutter build ipa --release
flutter build appbundle --release
```

**iOS 1.0.0 (13) + Android 1.2.0 (code 14), 2026-10-17:** carry the
Stupid Streak rework (six languages, no back-to-back repeats, self-contained
"opposite", YOU vs RIVAL scoring, round 2–3 sequence fix — see
[[iMessage Multiplayer]]). iOS: `flutter build ios --release --config-only
--build-name=1.0.0 --build-number=13`, `xcodebuild archive` with
`MARKETING_VERSION=1.0.0 CURRENT_PROJECT_VERSION=13` to
`build/ios/Runner-13.xcarchive` (app and extension both 1.0.0 (13)),
exported to `build/ios/export-13/AYS-ios-13.ipa` (SHA-256
`01bd072d2fb8cdd12931f0de4ce9e301a48b2a34e65e294cfe29ad361366f36b`); it
replaces 1.0.0 (12) in review. Android: `flutter build appbundle --release`,
`build/app/outputs/bundle/release/app-release.aab` (SHA-256
`6ec50b5c1ac0f1b2b1e0263072591096367a20104022e30e26cc0f4a9ab38889`,
`jarsigner` verified) for the closed-test Alpha track. 369/369 Flutter tests
and 11 iMessage core Swift tests green. Uploads need the owner: the
Chrome/Play file-input path is capped at 10 MB and App Store Connect needs an
interactive sign-in.

**iOS 1.0.0 (12) + tvOS 1.0.0 (12) + macOS 1.0.1 (14), 2026-10-14:**
App Review rejected tvOS 1.0.0 (11) on two grounds. Under 2.1(a) the reviewer's
iPhone showed "COULDN'T FIND ROOM … ON THIS WI-FI". Under 5.1.2 the tracking
label had no ATT on tvOS. macOS 1.0.1 (13) was rejected under 1.1.1 for the
app name. Build 12 adds the QR direct-connect hint (see
[[Multiplayer Protocol]]). iOS **must** ship together with it: build-11
clients reject a hinted QR link. Replies to App Review are recorded in
[[Decision Log]]. Same build steps as below with numbers 12/12/14; exports
are in `build/ios/export-12/AYS-ios-12.ipa`
(SHA-256 `f4299d5f3478025b0b44c4819cf99d4554821cc7257d9120327f39fe766c1b81`),
`build/hosts/tvos-export-12/AYS-tvos-12.ipa`
(`041aa33834217115c230dae03d620391082e636ddb555d7e63efb618c20c1baa`) and
`build/hosts/macos-export-14/AYS-mac-14.pkg`
(`427999f535fd5c89a5b99aa538beb23c075558b8738c45ca7dd5f01f33d360e1`).
368/368 Flutter tests and 84 Swift tests pass. All three were delivered with
Transporter on 2026-10-14. macOS 1.0.1 (14) was resubmitted with a reply to
App Review. iOS 1.0 (11) was withdrawn and iOS 1.0.0 (12) resubmitted with
its three in-app purchases. tvOS 1.0.0 (12) was resubmitted with the reply and
a pairing note in the review notes. All three are waiting for review.

**iOS 1.0.0 (11) + tvOS 1.0.0 (11) + macOS 1.0.1 (13), 2026-10-12:** the
2:25 submissions of builds 10/10/12 were withdrawn again to ship the
"ARE YOU STUPID?!" icon artwork, device-neutral permission/settings copy (no
"this phone" on iPad, Apple TV or Mac) and the spoken-name fix (ALEX was
announced as "ALE"). Same build steps with build numbers 11/11/13; exports
in `build/ios/export-11/`, `build/hosts/tvos-export-11/`,
`build/hosts/macos-export-13/`.
Resubmitted the same day; all three versions are set to **release
automatically** as soon as App Review approves them (owner's call). The
older approved Mac 1.0 (build 4) stays unreleased and is superseded by 1.0.1.

**iOS 1.0.0 (10) + tvOS 1.0.0 (10), 2026-10-12:** iOS 1.0.0 (7) and tvOS
1.0.0 (5) were withdrawn from review (developer rejected) to ship the
"ARE YOU STUPID?!" name everywhere and the board-host threading fix (see
[[Multiplayer Host (tvOS)]]). iOS: `flutter build ios --release --config-only
--build-name=1.0.0 --build-number=10`, then `xcodebuild archive` of
`ios/Runner.xcworkspace` with `MARKETING_VERSION=1.0.0
CURRENT_PROJECT_VERSION=10` (so the Stupid Streak extension matches) to
`build/ios/Runner-10.xcarchive`, exported to `build/ios/export-10/`. tvOS:
archived unsigned to `build/hosts/tvos-10.xcarchive`, signed at export to
`build/hosts/tvos-export-10/`. Exports are named after `CFBundleName`
(`ARE YOU STUPID?!.ipa`); copy to a name without `?!` before opening in
Transporter. New store screenshots (iPhone 6.9", iPad 13", Apple TV, Mac) were
uploaded and all three platforms resubmitted on 2026-10-12, iOS together with
its three in-app purchases.

**macOS 1.0.1 (12), 2026-10-12:** supersedes the approved-but-unreleased Mac
1.0 build 4 (the board-only host). App Store Connect cannot swap the build of
an approved version (no developer reject) and closes the 1.0.0 train once a
build is approved — build 1.0.0 (10) was refused with errors 90186/90062 — so
the Mac ships as a new **macOS version 1.0.1**. This is the Flutter Mac app —
single player plus HOST/PLAY party mode — shown as "ARE YOU STUPID?!", ad-free
with real StoreKit purchases (see [[Monetization and Ads]]); 362/362 tests
green. Build 11 was replaced by **12** to carry the "ARE YOU STUPID?!" name (see
[[Game Design Pillars]]). Built with `flutter build macos --release
--build-name=1.0.1 --build-number=12`, archived from `macos/Runner.xcworkspace`
(scheme `Runner`) to `build/hosts/macos-12.xcarchive`, exported to
`build/hosts/macos-export-12/` (the PKG is named after `CFBundleName`; copy it
to a name without `?!` before opening it in Transporter), delivered with
Transporter.
Store copy: `store_assets/app-store-mac-1.0.1.md`; screenshots:
`python3 store_assets/generate_mac_screenshots.py`. The macOS 1.2.0 (9) package
below predates the ad-free fix and must not be uploaded.

**1.2.0 release set, completed 2026-10-11:** all uploadable artifacts are
collected under `build/releases/1.2.0/`:

- iOS **1.2.0 (8)** — `ios/Are You Stupid.ipa`, SHA-256
  `1f589d02b917b190d2d012c067ad80c149bbec08a4c01bd7ab85683b7d640482`;
- tvOS **1.2.0 (9)** — `tvos-export/Are You Stupid.ipa`, SHA-256
  `665e967af2df5d1828e4b081f0d9b21e916c35cc618bac26d14e77933d2d25a7`;
- macOS **1.2.0 (9)** — `macos-export/are_you_stupid.pkg`, SHA-256
  `018f075ece036d2b7fc57516b143ee5aad253647161cb027c9dc1609c015e600`;
- Android **1.2.0 (code 9)** —
  `android/are-you-stupid-1.2.0-9.aab`, SHA-256
  `123f89dd4585288bd2c1963eee80b9d6e6f57a3327a5c9fd3dfbe9f665b9a0b9`.

iOS and tvOS pass deep `codesign` verification with Apple Distribution team
`G48384PHQK`; the macOS product archive is exported with Cloud Managed Apple
Distribution and the PKG carries the Apple-issued Mac installer signature.
The Android AAB passes `jarsigner` verification with the PynkStudio upload
certificate; `android/local.properties` records versionName 1.2.0 and
versionCode 9. Flutter still prints the documented native-symbol stripping
warning, but retains the debug symbols inside the valid signed AAB. Upload and
the real-device manual pass remain required.

The original iOS archive was built at `build/ios/ipa/Are You Stupid.ipa`
(SHA-256
`1f589d02b917b190d2d012c067ad80c149bbec08a4c01bd7ab85683b7d640482`).
The containing app and Stupid Streak extension both report 1.2.0 (8); the
export is signed with Apple Distribution team `G48384PHQK`, passes deep
`codesign` verification, contains 11 dependency privacy manifests, and no
longer uses Flutter's placeholder launch image. The tvOS Release target and
Flutter macOS Release app also build successfully. `pubspec.yaml` is left at
`1.2.0+10`, ready for the next archive. Localized What's New copy is in
`store_assets/app-store-1.2.0.md`. Upload and the real-device manual pass are
still required.

**Android 1.1.0 (code 5), 2026-10-06:** `flutter analyze` clean,
**350/350** tests green, AAB signed with the upload key (certificate
`CN=Are You Stupid, O=PynkStudio`) at
`build/app/outputs/bundle/release/app-release.aab`. The build left
`pubspec.yaml` at `1.1.0+6` — see the versionCode caveat in
[[Getting Started]].

**1.0.0 (2), 2026-10-02:** all three store packages built and signed for
distribution from commit `f2c9439` (331/331 tests green):
`build/ios/export/Are You Stupid.ipa`, `build/hosts/tvos-export/Are You
Stupid.ipa`, `build/hosts/macos-export/Are You Stupid.pkg` (macOS re-built up to **build 3**: builds 1–2 were rejected for an invalid `LSApplicationCategoryType`; tvOS re-built as **build 2** with proper layered icons). Delivered with Transporter on 2026-10-02. The tvOS host is
archived with `CODE_SIGNING_ALLOWED=NO` and signed at export — automatic
signing can't make a tvOS *development* profile without a registered Apple
TV. `xcodebuild -exportArchive` with `destination: upload` failed with
"Credentialed provider request failed … providerId": re-add the Apple ID in
Xcode → Settings → Accounts, or upload with Transporter.

Upload `build/ios/ipa/*.ipa` with Transporter (or Xcode Organizer) and
`build/app/outputs/bundle/release/app-release.aab` in Play Console. Hosts:
open `tvos/AYSHost.xcodeproj`, scheme `AYSHost-tvOS`,
*Product → Archive → Distribute → App Store Connect*. Mac (since 2026-10-05
the only Mac product, embedding the board host): `flutter build macos
--release`, then archive `macos/Runner.xcworkspace` (scheme `Runner`) and
distribute the same way.

**1.0.0 (4), 2026-10-03:** the current dirty-worktree release was verified
with clean `flutter analyze` and **350/350** passing tests, then exported as
`build/ios/ipa/Are You Stupid.ipa`,
`build/hosts/tvos-export-4/Are You Stupid.ipa`, and
`build/hosts/macos-export-4/Are You Stupid.pkg`. All three archives report
build 4. The three builds are uploaded to App Store Connect and associated
with their platform versions. All platform screenshots and the reviewer
screenshot for each in-app purchase are uploaded. iOS (including all three
in-app purchases), macOS and tvOS were submitted on 2026-10-03 and are waiting
for review.

**1.1.0 (5), 2026-10-03:** iOS-only TestFlight candidate containing the
native Stupid Streak Messages extension. The containing app and
`StupidStreak.appex` both report 1.1.0 (5), the archive signature validates,
and Transporter accepted the delivery at 19:02. App Store Connect processing
was still running at handoff. This does not replace or alter the tvOS/macOS
1.0 submission.

## Manual pass (do it on a real phone, in portrait, one hand)

- [ ] First launch in the EEA: consent form, then ATT (iOS), then home
- [ ] Menu → PLAY starts in under a second
- [ ] Ten runs in a row: nothing repeats back to back, levels 1–3 stay trivial
- [ ] Every flash is readable at arm's length; a mashed tap can't skip the
      roast or hit a Game Over button
- [ ] TRY AGAIN restarts in under a second
- [ ] CONTINUE (rewarded) resumes the same level after a READY beat, once per run
- [ ] Remove ads: buy, kill app, reinstall, restore
- [ ] Share sheet opens with the right text and link
- [ ] Sound off / vibration off actually silences everything
- [ ] Airplane mode: the game is fully playable
- [ ] Kill and relaunch: best score and settings survived
- [ ] Multiplayer permissions (iOS, **release** build, fresh install): no
      Local Network prompt before MULTIPLAYER; primer → CONTINUE → system
      prompt. Deny it: the OPEN SETTINGS notice appears, opens Settings,
      and disappears on return once access is on. Revoke it later in
      Settings: the notice comes back on the next visit
- [ ] Multiplayer: Apple TV host + iPhone + Android in one room; with an
      Apple-Intelligence iPhone in the room the Android phone still plays
      AI rounds
- [ ] Apple Intelligence on a real iOS 26 device — never verified on
      hardware yet ([[Testing and Evaluation]])
