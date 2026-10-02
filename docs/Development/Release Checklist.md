---
tags: [development, release]
updated: 2026-10-02
---

# Release Checklist

Version **1.0.0**. One App Store record ships three platforms (universal
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
- [ ] In-app purchase `ays_remove_ads` (non-consumable): created, priced,
      review notes in. **Still needs the review screenshot** (Settings with
      the REMOVE ADS row) and must be **attached to the first iOS
      submission** — otherwise review can't find it
- [x] App Privacy published 2026-10-02: **Data used to track you** — Device ID (IDFA),
      Advertising Data, Product Interaction, Coarse Location, Diagnostics
      (all from the Google Mobile Ads SDK). *Not* "no data collected"
- [x] Privacy Policy URL `https://pynkstudio.eu/it/lavori/are-you-stupid/privacy`;
      Support/Marketing URL the `/en` game page
- [x] Age rating questionnaire: frequent profanity/crude humor, ads →
      **13+** (12+ in Vietnam/Korea)
- [x] Description, promo text, keywords, support/marketing URLs, review
      notes and contact filled for iOS, tvOS and macOS versions (party-game
      positioning; no claims about features not shipped, e.g. on-screen AI
      commentary or online leaderboards)
- [x] Review notes: multiplayer needs the Apple TV / Mac host on the same
      Wi-Fi; Apple Intelligence features need an iOS 26 eligible device and
      fall back to scripted challenges otherwise
- [ ] Screenshots: iPhone has 4 (6.5") from an older build — refresh with
      party-mode shots; still missing iPad 13", Apple TV (1920×1080), Mac
      (≥1280×800). Suggested phone set: instruction frame, green flash, red
      roast, Game Over card

## Google Play Console

- [ ] App created, package `com.ays.are_you_stupid`, Play App Signing on
- [ ] Data safety: advertising ID + app interactions + diagnostics shared
      with Google for advertising; no account; data encrypted in transit
      (HTTPS)
- [ ] Advertising ID declaration: yes (AdMob)
- [ ] Contains ads: yes. Target audience: 13+ (avoid "Designed for
      Families" — the language rules it out)
- [ ] Content rating (IARC) questionnaire: crude humor, profanity
- [ ] In-app product `ays_remove_ads` created and active
- [ ] Internal testing track first, then production
- [ ] Feature graphic 1024×500 + phone screenshots

## Builds

```bash
flutter build ipa --release
flutter build appbundle --release
```

**1.0.0 (2), 2026-10-02:** all three store packages built and signed for
distribution from commit `f2c9439` (331/331 tests green):
`build/ios/export/Are You Stupid.ipa`, `build/hosts/tvos-export/Are You
Stupid.ipa`, `build/hosts/macos-export/Are You Stupid.pkg`. The tvOS host is
archived with `CODE_SIGNING_ALLOWED=NO` and signed at export — automatic
signing can't make a tvOS *development* profile without a registered Apple
TV. `xcodebuild -exportArchive` with `destination: upload` failed with
"Credentialed provider request failed … providerId": re-add the Apple ID in
Xcode → Settings → Accounts, or upload with Transporter.

Upload `build/ios/ipa/*.ipa` with Transporter (or Xcode Organizer) and
`build/app/outputs/bundle/release/app-release.aab` in Play Console. Hosts:
open `tvos/AYSHost.xcodeproj`, scheme `AYSHost-tvOS` / `AYSHost-macOS`,
*Product → Archive → Distribute → App Store Connect*.

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
