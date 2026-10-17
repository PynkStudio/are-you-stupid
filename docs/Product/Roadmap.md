---
tags: [product, roadmap]
updated: 2026-10-17
---

# Roadmap

Release state lives in [[Release Checklist]]: 1.0.0 is the production
submission, 1.1.0 is on TestFlight (adds Stupid Streak), 1.2.0 is the current
release candidate (adds the multiplayer presenter). **Scope is frozen for
those three trains** — only fixes and release gates go in. Everything under
"1.3.0 and later" waits until 1.2.0 is out (see [[Decision Log]]).

## Shipped (1.0.0 → 1.2.0, in store submission)

- Main menu, 39 challenge templates, random selection, difficulty progression
- Score + best score + stats, Game Over, one-tap retry
- Real AdMob ads (interstitial + rewarded continue) behind GDPR/UMP consent
  and ATT; "remove ads" IAP ([[Monetization and Ads]])
- Share result with a link to the game page ([[Virality and Sharing]])
- Settings, a small reviewed generated SFX bank (the audio exception in
  [[Game Design Pillars]]), haptics, local persistence, fully offline play
- Six languages ([[Localization]])
- **Apple TV / Mac party mode** — phones as controllers, tvOS and macOS
  board hosts shipped in the same App Store record ([[Multiplayer Product]],
  [[Multiplayer Host (tvOS)]])
- **AI dynamic director (Apple Intelligence, iOS only)** — generated
  challenges in all six languages, on-screen commentary (wrong-flash aside +
  Game Over verdict), multiplayer AI Director; scripted fallback everywhere;
  off on Android, where phones still play AI rounds relayed by an iOS
  Director ([[Dynamic AI Director]], [[AI Commentary]], [[Feature Flags]])
- **Stupid Streak for iMessage (1.1.0, release-gated)** — native
  asynchronous 1v1, same seeded challenge streak for both players, three
  disproportionately harder rounds, no backend ([[iMessage Multiplayer]]).
- **Multiplayer Presenter foundation (1.2.0)** — optional online voice host
  with an offline fallback pack ([[Multiplayer Presenter]]).

## Release gates (before 1.2.0 goes live — no new features)

1. **Real-device manual pass** for the phone game ([[Release Checklist]]).
2. **Stupid Streak two-device Messages pass** — its copy is now localized in
   the six game languages (2026-10-17, [[iMessage Multiplayer]]).
3. **Real-device AI evaluation** — generation quality has never run on
   hardware ([[Testing and Evaluation]]).
4. **Multiplayer real-device validation** — 2, 4 and 8 phones on one Wi-Fi
   (Phase 10 in [[Multiplayer Development]]).
5. **Presenter production config** — backend voice ID, licensed offline
   pack, tvOS audio check ([[Multiplayer Presenter]]).

## 1.3.0 and later, in rough order of value

1. **Daily challenge** — a seeded run everyone gets the same day (seed =
   date), with a Wordle-style share line (`#42 — LEVEL 17 🟩🟩🟥`). Still
   offline; the generator is already deterministic for multiplayer and
   Stupid Streak. The only feature that gives a reason to come back daily.
2. **Share the Game Over card as an image** — render the card (with KILLED
   BY) to PNG and attach it to the share text. Today sharing is text-only,
   yet the card is the joke the screenshot travels on
   ([[Virality and Sharing]]).
3. **Color-blind mode** — many templates judge by color, and "IT WAS
   ORANGE" is not a one-line explainable failure for a color-blind player
   ([[Game Design Pillars]]). Options: pair colors with shapes/patterns, or
   exclude color templates. Also check the green/red flash contrast.
4. **Offline retention** — a "Hall of Shame" in Stats (the challenge that
   killed you most, with its share), local stupid medals ("died on level 1",
   "killed 10 times by the same thing"), and a "rematch that challenge"
   action on the Game Over card. All stored locally
   ([[State and Persistence]]).
5. **More templates**, starting with the families thinnest in the
   [[Challenge Catalog]]. The cheapest way to add depth: see
   [[Adding a Challenge]].
6. **Multiplayer game-show polish** — elimination card, winner animation,
   share card, TV humor lines (Phase 9 in [[Multiplayer Development]]).
7. **Playtest pass** — 5–10 first-time players, watching where they quit.
   With no analytics, this is the only way to tune [[Difficulty Curve]] and
   ad pacing.
8. **Replay clip export** — record the last 10 s to camera roll.
   Highest-effort, highest-reward for TikTok; builds on item 2.

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
