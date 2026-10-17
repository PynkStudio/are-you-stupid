---
tags: [architecture, persistence, offline]
updated: 2026-10-17
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
| `ays.mp.permissionsPrimerSeen` | the multiplayer permissions primer was accepted; until then nothing touches the local network — see [[Multiplayer Client (Mobile)]] |
| `ays.noAdsPurchased` | the "remove ads" IAP, set by `PurchaseManager` after a store purchase or restore — see [[Monetization and Ads]] |
| `ays.partyPackPurchased` | Party Pack IAP: 16-player room entitlement only — see [[Multiplayer Product]] |
| `ays.partyBundlePurchased` | Party Bundle IAP: 16-player room entitlement plus no ads — see [[Multiplayer Product]] |
| `ays.mp.personaId` | random anonymous multiplayer persona, stable across joins; contains no player name |
| `ays.mp.verifiedDisplayName` | exact display name for which presenter pronunciation was classified |
| `ays.mp.spokenName` | cached validated pronunciation/alias for that exact display name |
| `ays.mp.speechPolicy` | cached presenter speech verdict for that exact display name |

The tvOS/macOS board separately keeps up to 64 presenter careers in its local
`UserDefaults` key `ays.presenter.careers.v1`, keyed by `personaId`; each
entry holds a title key (`titleKey`) and `lastSeen`. Older entries that stored
the spoken title text are read back by matching that text against every
shipped locale's wording and are dropped if it matches none. Positive
titles expire after 90 days; performance-negative titles after 7. It is not a
cloud profile and is never sent to the speech backend ([[Multiplayer Presenter]]).

### AI feature keys (`ayu.*`, spec — [[Feature Flags]], [[Privacy and Offline]])

| Key | Meaning |
|---|---|
| `ayu.dynamicAI.mode` | AI Experience Modes: `genius \| focused \| classic` |
| `ayu.dynamicAI.*` | per-flag tri-state overrides (`aiChallengeGenerationEnabled`, …) |
| `ayu.profile` | rolling `PlayerGameplayProfile` (~2 KB, 50-round window, no identity) |
| `ayu.ai.observability.*` | local-only QA counters (dev screen) |

All `ayu.*` keys are wiped by Settings → RESET STATS *and* revert to shipped
defaults; nothing touches them except the `lib/ai/` layer
([[Privacy and Offline]] → "What's persisted").

## Run state vs stored state

`GameState` (in memory, one run) and `ScoreManager` (on disk, forever) are
deliberately separate. The engine never writes to disk; `GameScreen` records the
run once, on `GameEvent.gameOver`.

Runs extended with a rewarded continue are recorded with `countAttempt: false`,
so continues update the best level but do not inflate attempts or the average.

## Resetting

Settings → RESET STATS wipes the score keys (`ays.best`, `ays.attempts`,
`ays.levelSum`, `ays.streak`, `ays.runsSinceAd`) via `ScoreManager.reset()`,
plus the AI keys (`ayu.*`) via the `lib/ai/` reset path
([[Privacy and Offline]]). Sound/haptics/roasts/language and
`ays.noAdsPurchased`, `ays.partyPackPurchased` and
`ays.partyBundlePurchased` are untouched — purchases are not "progress" and must
survive a stats reset. There is no UI path that removes it short of
reinstalling and not restoring, and nothing leaves the phone either way.
