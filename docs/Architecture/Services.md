---
tags: [architecture, services]
updated: 2026-09-06
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
| `SoundManager` | correct / wrong / level / record / button | platform system sounds, no assets |
| `HapticManager` | correct / wrong / record / tap | `HapticFeedback` |
| `ShareManager` | share text + OS share sheet | `share_plus` |
| `AdManager` | *policy*: when ads may show | see [[Monetization and Ads]] |
| `PurchaseManager` | *policy*: buy/restore the "remove ads" IAP | `ChangeNotifier`, see [[Monetization and Ads]] |

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
other locale to its `/en` counterpart — see [[Decision Log]] for why (and the
open item to verify that `/en` page is actually live before release). The
privacy policy stays a single URL for every locale; it's deliberately
English-only.

## Sound without assets

`SoundManager` talks to a `SoundBackend`. The default `SystemSoundBackend` uses
`SystemSound.play()`. To ship real sfx later, implement `SoundBackend` and pass
it to the constructor — nothing else changes.

**Only `SystemSoundType.click` actually plays anything.** The Flutter engine's
own Android (`PlatformPlugin.playSystemSound`) and iOS
(`FlutterPlatformPlugin.playSystemSound`) implementations only handle `click`
(iOS also handles `tick`, Android doesn't); `alert` is a silent no-op on both
platforms — confirmed by reading the engine source, not assumed. `SoundBackend`
therefore exposes `click()` only, and every distinct cue (`correct`, `wrong`,
`record`, ...) is built from repeated clicks with different timing, never a
different `SystemSoundType`. `wrong()` originally called the non-existent
`alert()` and produced no sound at all on either platform — fixed by making it
two clicks 45 ms apart instead.

Even a working `click()` is quiet and, on Android, gated behind the system
"Touch sounds" setting (`Settings.System.SOUND_EFFECTS_ENABLED`) — off by
default on many devices, and entirely outside this app's control without
bundling real audio, which [[Game Design Pillars]] rules out. Don't expect it
to sound like game SFX; it's a UI click, at best.

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
