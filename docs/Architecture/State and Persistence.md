---
tags: [architecture, persistence, offline]
updated: 2026-09-06
---

# State and Persistence

## Offline-first, and that is final

No backend, no account, no cloud save, no analytics SDK, no network permission
needed. Everything lives in `SharedPreferences` on the device.

| Key | Meaning |
|---|---|
| `ays.best` | best level ever reached — **the** score |
| `ays.attempts` | finished runs |
| `ays.levelSum` | sum of reached levels (→ average) |
| `ays.streak` | best "fast answer" streak |
| `ays.runsSinceAd` | interstitial pacing counter |
| `ays.sound`, `ays.haptics`, `ays.roasts` | settings |
| `ays.locale` | chosen language; absent = follow the device language — see [[Localization]] |
| `ays.noAdsPurchased` | the "remove ads" IAP, set by `PurchaseManager` after a store purchase or restore — see [[Monetization and Ads]] |

## Run state vs stored state

`GameState` (in memory, one run) and `ScoreManager` (on disk, forever) are
deliberately separate. The engine never writes to disk; `GameScreen` records the
run once, on `GameEvent.gameOver`.

Runs extended with a rewarded continue are recorded with `countAttempt: false`,
so continues update the best level but do not inflate attempts or the average.

## Resetting

Settings → RESET STATS wipes the score keys (`ays.best`, `ays.attempts`,
`ays.levelSum`, `ays.streak`, `ays.runsSinceAd`) via `ScoreManager.reset()`.
Sound/haptics/roasts/language and `ays.noAdsPurchased` are untouched — a
purchase is not "progress" and must survive a stats reset. There is no UI path
that removes it short of reinstalling and not restoring, and nothing leaves
the phone either way.
