---
tags: [product, roadmap]
updated: 2026-10-02
---

# Roadmap

## Shipped (1.0.0, in store submission)

- Main menu, 39 challenge templates, random selection, difficulty progression
- Score + best score + stats, Game Over, one-tap retry
- Real AdMob ads (interstitial + rewarded continue) behind GDPR/UMP consent
  and ATT; "remove ads" IAP ([[Monetization and Ads]])
- Share result with a link to the game page ([[Virality and Sharing]])
- Settings, system sounds, haptics, local persistence, fully offline play
- Six languages ([[Localization]])
- **Apple TV / Mac party mode** — phones as controllers, tvOS and macOS
  board hosts shipped in the same App Store record ([[Multiplayer Product]],
  [[Multiplayer Host (tvOS)]])
- **AI dynamic director (Apple Intelligence, iOS only)** — generated
  challenges, multiplayer AI Director; scripted fallback everywhere; off on
  Android, where phones still play AI rounds relayed by an iOS Director
  ([[Dynamic AI Director]], [[Feature Flags]])

## Next, in rough order of value

1. **Multiplayer game-show polish** — elimination card, winner animation,
   share card, TV humor lines (Phase 9 in [[Multiplayer Development]]).
2. **AI commentary on screen** — generated today but not displayed
   ([[AI Commentary]]); real-device evaluation of generation quality
   ([[Testing and Evaluation]]).
3. **More templates.** The cheapest way to add depth: see [[Adding a Challenge]].
4. **Daily challenge** — a seeded run everyone gets the same day. Pure virality,
   still offline (seed = date).
5. **Replay clip export** — record the last 10 s to camera roll. Highest-effort,
   highest-reward for TikTok.
6. **Real sound design** — today only the system click exists
   ([[Services]]); bundled synthesized cues would need a pillar exception.

## Deliberately out of scope

Login, backend, cloud save, online leaderboard, subscriptions, characters, 3D,
external art. See [[Game Design Pillars]] before proposing any of them.

Note: the **multiplayer** slice is also explicitly scoped to keep out online
matchmaking, accounts, cloud saves, global leaderboards, voice/video chat and
cosmetics — any of those is a separate conversation ([[Multiplayer Product]]).

Note: the **AI** slice follows the same discipline — on-device only, no
server, no player identity, no analytics, and the model is never the
authority (validator is). Violating any of that is out of scope
([[Privacy and Offline]]).
