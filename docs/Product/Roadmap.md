---
tags: [product, roadmap]
updated: 2026-09-06
---

# Roadmap

## Shipped (MVP)

- Main menu, 39 challenge templates, random selection, difficulty progression
- Score + best score + stats, Game Over, one-tap retry
- Mock rewarded + interstitial ads, share result
- Settings, system sounds, haptics, local persistence, fully offline

## Next, in rough order of value

1. **Apple TV party mode (multiplayer).** A 2–8 player game hosted on tvOS
   with iPhone/iPad controllers over the local network. Full spec in the
   [[Multiplayer Product]] / [[Multiplayer Architecture]] / [[Multiplayer
   Protocol]] notes; build order in [[Multiplayer Development]]. This
   supersedes the daily-challenge idea below as the biggest virality lever.
2. **Real ad SDK** behind the existing `AdProvider` ([[Monetization and Ads]]).
3. **Store polish** — app icon, launch screen, screenshots, store copy.
   The game generates its own visuals, but the store listing needs assets.
4. **More templates.** The cheapest way to add depth: see [[Adding a Challenge]].
5. **Daily challenge** — a seeded run everyone gets the same day. Pure virality,
   still offline (seed = date).
6. **Replay clip export** — record the last 10 s to camera roll. Highest-effort,
   highest-reward for TikTok.

## Deliberately out of scope

Login, backend, cloud save, online leaderboard, subscriptions, characters, 3D,
external art. See [[Game Design Pillars]] before proposing any of them.

Note: the **multiplayer** slice is also explicitly scoped to keep out online
matchmaking, accounts, cloud saves, global leaderboards, voice/video chat and
cosmetics — any of those is a separate conversation ([[Multiplayer Product]]).
