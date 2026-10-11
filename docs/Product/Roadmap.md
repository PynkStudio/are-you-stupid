---
tags: [product, roadmap]
updated: 2026-10-03
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
- **Stupid Streak for iMessage (code complete, release-gated)** — native
  asynchronous 1v1, same seeded challenge streak for both players, three
  disproportionately harder rounds, no backend ([[iMessage Multiplayer]]).
  Simulator build and core tests pass; two-device Messages validation and
  native-copy localization remain before store release.

## Next, in rough order of value

1. **Multiplayer game-show polish** — elimination card, winner animation,
   share card, TV humor lines (Phase 9 in [[Multiplayer Development]]).
2. **Multiplayer Presenter** — prototype the optional online, cache-first
   charismatic voice host, spoken-name precheck and match-local narrative
   titles ([[Multiplayer Presenter]]).
3. **AI commentary on screen** — generated today but not displayed
   ([[AI Commentary]]); real-device evaluation of generation quality
   ([[Testing and Evaluation]]).
4. **More templates.** The cheapest way to add depth: see [[Adding a Challenge]].
5. **Daily challenge** — a seeded run everyone gets the same day. Pure virality,
   still offline (seed = date).
6. **Replay clip export** — record the last 10 s to camera roll. Highest-effort,
   highest-reward for TikTok.
7. **Real sound design** — today only the system click exists
   ([[Services]]); general bundled cues still need a pillar exception beyond
   the narrowly approved [[Multiplayer Presenter]] fallback bank.
8. **Localize Stupid Streak and run its two-device gate** — the native v1
   extension currently has English copy; verify a complete six-message match
   between physical devices before enabling it in the submitted build
   ([[iMessage Multiplayer]]).

## Demand-gated opportunities (not prioritized)

- **Browser-based multiplayer host** — let groups without an Apple TV or Mac
  run the shared board from a web page. This is documented as a possible
  post-launch expansion, not committed roadmap work. Reconsider it only after
  the game has reached a meaningful sustained average-user base and/or direct
  user requests show that Apple-only host availability is materially blocking
  parties. A production version would require a new WebSocket room service and
  client transport because browsers cannot replace the current LAN TCP +
  Bonjour host directly; see [[Multiplayer Product]]. No discovery, design or
  implementation work is scheduled before those demand signals exist.

## Deliberately out of scope

Login, general-purpose backend, cloud save, online leaderboard, subscriptions,
characters, 3D, external art. The narrowly scoped optional presenter backend
is the current exception; a browser multiplayer host is a separately documented
demand-gated possibility, not an approved backend expansion. See
[[Multiplayer Presenter]] and [[Multiplayer Product]].

Note: the **multiplayer** slice is also explicitly scoped to keep out online
matchmaking, accounts, cloud saves, global leaderboards, voice/video chat and
cosmetics — any of those is a separate conversation ([[Multiplayer Product]]).

Note: the **AI** slice follows the same discipline — on-device only, no
server, no player identity, no analytics, and the model is never the
authority (validator is). Violating any of that is out of scope
([[Privacy and Offline]]).
