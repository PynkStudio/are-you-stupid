---
tags: [architecture, services]
updated: 2026-10-06
---

# Services

`lib/services/` — everything that talks to the platform. Injected at the root
through `AppServices` + `ServicesScope` (a plain `InheritedWidget`, no DI
package).

```dart
final services = AppServices.of(context);
```

| Service | Responsibility | Notes |
|---|---|---|
| `SettingsManager` | sound / vibration / savage mode / language | `ChangeNotifier`, SharedPreferences |
| `ScoreManager` | best level, attempts, average, streak, ad counter | `ChangeNotifier`, SharedPreferences |
| `SoundManager` | correct / wrong / level / record / button | bundled generated SFX through `audioplayers`, fixed 32% gain |
| `HapticManager` | correct / wrong / record / tap | `HapticFeedback` |
| `ShareManager` | share text + OS share sheet | `share_plus` |
| `AdManager` | *policy*: when ads may show; consent (UMP) + ATT before the SDK starts | started post-frame via `AppServices.startAds()`, never during the splash — see [[Monetization and Ads]] |
| `PurchaseManager` | *policy*: buy/restore Remove Ads + Party Pack + Party Bundle IAPs | `ChangeNotifier`, see [[Monetization and Ads]] |
| `LocalNetworkPermission` | multiplayer Local Network permission + active Wi-Fi transport probes, and "open this app's Settings" | `ays/permissions` MethodChannel (`PermissionsController.swift`, `MainActivity.kt`); never exposes SSID/BSSID, never throws, and returns `unknown` when the channel or a reliable platform answer is missing — see [[Multiplayer Client (Mobile)]] "Permissions" |
| `AppleAIService` (Phase 2) | on-device Foundation Models client via the `ays/apple_intelligence` MethodChannel | `lib/ai/apple_ai_service.dart` + `AppleAIController.swift`; `available` real, generation stubbed until Phases 4–5 ([[Foundation Models Integration]]); `MockAppleAIService` for tests |

The **dynamic AI director** itself is *not* a service — it's the
`lib/ai/` layer (providers, validator, prefetch cache, telemetry) that lives
*above* `lib/services/`. Services stay platform-facing; `AppleAIService` is
the **only** AI-related member of this table and its whole job is to own that
one channel. See [[Dynamic AI Director]].

### Boot order

`AppServices.boot()` (behind the animated splash) loads prefs and starts
purchases with a **4 s cap** — it no longer awaits the ads SDK at all.
`main.dart` then calls `startAds()` after the first frame of `HomeScreen`,
because the GDPR consent form and the iOS ATT prompt are native UI that must
appear over an active app. Nothing in gameplay waits on either.

## External links

The Settings screen opens two PynkStudio pages — "ABOUT THE GAME" (the game's
public case-study page) and "PRIVACY POLICY" — plus a "Made by PynkStudio"
credit, all via `url_launcher` (`LaunchMode.externalApplication`, i.e. the
device's own browser, never an in-app `WebView`). This isn't wrapped in its
own service class: it's a couple of static URLs and a one-line `launchUrl`
call directly in `settings_screen.dart`, not stateful enough to earn an
abstraction. Android needs a `<queries>` entry for `android.intent.action
.VIEW` + `https` in `AndroidManifest.xml` for this to resolve on API 30+
(package visibility); iOS needs nothing extra for `https` links. Gameplay
itself stays fully offline ([[Game Design Pillars]]) — these rows are an
explicit, player-initiated exit to the browser, the same category as the ads
`AdManager` already gates.

The "about" URL is the one place this picks a link by `AppLocale`:
`_gameInfoUrlFor` sends Italian to the Italian case-study page and every
other locale to its `/en` counterpart — see [[Decision Log]] for why. Both
pages were verified live on 2026-10-02. The URL pair is owned by
`ShareManager.landingUrlFor`, which also appends it to shared results
([[Virality and Sharing]]). The
privacy policy stays a single URL for every locale; it's deliberately
English-only.

## Generated sound effects

`SoundManager` maps its five semantic `SoundCue`s to reviewed MP3s under
`assets/audio/sfx/`; `AssetSoundBackend` plays them through `audioplayers` in
low-latency mode. Every play supplies a hard-coded `0.32` linear gain because
the generated masters are uncomfortably loud at full scale in headphones.
Decode failure falls back to the platform click rather than surfacing an error
or affecting play. `SoundBackend` remains injectable so tests assert semantic
selection and the Settings gate without invoking a platform audio plugin.

## Settings gate everything

Both `SoundManager` and `HapticManager` check `SettingsManager` on every call,
so a disabled toggle is honoured everywhere by construction.

**Android needs `android.permission.VIBRATE`** in `AndroidManifest.xml` for
`HapticManager`'s `HapticFeedback.*` calls to vibrate reliably — a normal
permission (no runtime prompt, no store disclosure), but silently a no-op on
some devices/OEMs without it. Also: neither the iOS Simulator nor most Android
emulators have a working haptic engine, so "no vibration" when testing there
is expected, not a bug — verify on a real device.

"Savage mode" off means the engine only draws from the neutral roast pool
(`GameEngine.spicyRoasts`) — see [[Humor and Roasts]].

## Language

`SettingsManager.locale` returns the saved choice, or the device language
(falling back to English) when the player never picked one —
`localeIsSystemDefault` tells the Settings screen which to show. Screens read
it directly and look strings up with `Strings.t`; `GameEngine.locale`
forwards it into `ChallengeGenerator` so challenges build in the right
language. See [[Localization]].
