---
tags: [development, release]
updated: 2026-09-06
---

# Release Checklist

## Code

- [x] `flutter analyze` — zero issues (verified 2026-09-06)
- [ ] `flutter test` — 38 tests across 5 suites, but **one is intermittently
      flaky** (`app_flow_test.dart`, "the run is recorded in the stats
      screen", ~1 in 5–8 runs) — a genuine `RenderFlex` overflow in
      `StatsScreen`, not a test bug. See [[Testing]] before treating this as a
      hard gate
- [x] `docs/` updated ([[Documentation Rules]])
- [ ] Version bumped in `pubspec.yaml` — still `0.1.0+1`; bump when the first
      store submission is actually ready

## Product

- [ ] `ShareManager.storeUrl` filled with the real store link — can only be
      done once the store listing exists ([[Virality and Sharing]])
- [x] Real `AdProvider` wired in `main.dart` — `AdMobAdProvider`, real AdMob
      IDs ([[Monetization and Ads]])
- [ ] App icon and launch screen replaced — **still the Flutter default logo**
      on both platforms (`android/app/src/main/res/mipmap-*/ic_launcher.png`,
      `ios/Runner/Assets.xcassets/AppIcon.appiconset/`) and the default blank
      splash (`android/.../launch_background.xml`,
      `ios/.../LaunchImage.imageset/`)
- [ ] Bundle id / application id: Android is `com.ays.are_you_stupid`, iOS is
      `com.ays.areYouStupid` — different casing, never unified. Not a
      functional problem but worth a conscious decision before submission
- [x] Android release build signs with a real upload key, not the debug key —
      `android/key.properties` (gitignored, never commit it) points
      `signingConfigs.release` at `android/upload-keystore.jks` (also
      gitignored); falls back to debug signing only when `key.properties` is
      absent, e.g. a fresh checkout ([[Decision Log]])
- [x] Android launcher label is a real name (`Are You Stupid`), not the raw
      package name (`are_you_stupid`)
- [ ] Privacy policy written, published somewhere public, and its URL entered
      in both consoles. Mandatory for both stores, more so here because the
      app ships AdMob + App Tracking Transparency (device/ad identifiers).
      Say plainly that the game itself collects nothing — see [[Monetization
      and Ads]]
- [ ] iOS signing confirmed in Xcode before archiving: `DEVELOPMENT_TEAM` is
      already set (`G48384PHQK`), but the archive step needs an active Apple
      Developer Program membership and a distribution certificate, not just
      the "iPhone Developer" identity used for local runs

## Manual pass (do it on a real phone, in portrait, one hand)

- [ ] Menu → PLAY starts in under a second
- [ ] Ten runs in a row: nothing repeats back to back, levels 1–3 stay trivial
- [ ] Every flash is readable at arm's length
- [ ] TRY AGAIN restarts in under a second
- [ ] CONTINUE (rewarded) resumes the same level, once per run
- [ ] Share sheet opens with the right text
- [ ] Sound off / vibration off actually silences everything
- [ ] Airplane mode: the game is fully playable
- [ ] Kill and relaunch: best score and settings survived
- [ ] Screen-record a run vertically: it reads at thumbnail size

## Store

- [ ] Screenshots: instruction frame, green flash, red roast, Game Over card
- [ ] Age rating reflects the language ("DON'T FUCK IT UP", roasts)
- [ ] Privacy: no data collected, no account, no network — say so
