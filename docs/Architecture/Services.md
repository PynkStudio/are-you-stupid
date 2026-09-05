---
tags: [architecture, services]
updated: 2026-09-05
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
| `SettingsManager` | sound / vibration / savage mode | `ChangeNotifier`, SharedPreferences |
| `ScoreManager` | best level, attempts, average, streak, ad counter | `ChangeNotifier`, SharedPreferences |
| `SoundManager` | correct / wrong / level / record / button | platform system sounds, no assets |
| `HapticManager` | correct / wrong / record / tap | `HapticFeedback` |
| `ShareManager` | share text + OS share sheet | `share_plus` |
| `AdManager` | *policy*: when ads may show | see [[Monetization and Ads]] |

## Sound without assets

`SoundManager` talks to a `SoundBackend`. The default `SystemSoundBackend` uses
`SystemSound.play()`. To ship real sfx later, implement `SoundBackend` and pass
it to the constructor — nothing else changes.

## Settings gate everything

Both `SoundManager` and `HapticManager` check `SettingsManager` on every call,
so a disabled toggle is honoured everywhere by construction.

"Savage mode" off means the engine only draws from the neutral roast pool
(`GameEngine.spicyRoasts`) — see [[Humor and Roasts]].
