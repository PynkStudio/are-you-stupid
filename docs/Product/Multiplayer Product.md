---
tags: [product, multiplayer, party]
updated: 2026-09-07
---

# Multiplayer Product

The party-mode product concept and scope for **ARE YOU STUPID?** — a
controller-led party game, building on the design pillars in
[[Game Design Pillars]] without breaking them.

## Concept

The tagline stays **YOU HAD ONE JOB.**

The party mode is for a group sitting in front of a shared screen:

- The **board is the game master** ([[Multiplayer Host (tvOS)]]) — an Apple TV,
  or a **Mac in board-only mode** (host + display, no direct play on the Mac;
  see below).
- Each player uses their **own iPhone/iPad as a controller**
  ([[Multiplayer Client (Mobile)]]).
- Everyone receives the **same challenge simultaneously**
  ([[Multiplayer Challenges]]).
- The challenges are intentionally simple, but layer in misleading
  instructions, timing traps, visual tricks and psychological mistakes.
- The fun is **watching friends fail.**

## Player experience (2-8 players)

1. Open ARE YOU STUPID? on Apple TV **(or on your Mac — the Mac hosts the
   room board-only, and you play on your phone like everyone else)**.
2. The board creates a local room and shows a QR code.
3. Players scan the QR with their phones → the mobile app opens.
4. The player joins the room ({NAME} + optional emoji), name appears on the board.
5. Everyone presses READY; the host starts when ≥2 are ready.
6. The same challenge appears on every connected device.
7. Players answer independently; the board shows live results and rankings.
8. Players are eliminated ([[Multiplayer Gameplay|Last Stupid Standing]]) or
   accumulate points ([[Multiplayer Gameplay|Stupid Battle]]).
9. The last player standing / highest scorer wins.
10. Instantly rematch or return to menu.

No account, no cloud, no internet once installed ([[Game Design Pillars]]).

## macOS as the host (board-only, no direct play)

The macOS build of the host runs the **exact same host core and screens as
tvOS**, so groups without an Apple TV can host from any Mac:

- It is **board-only by design**: the Mac hosts, displays, and owns the rules —
  the person at the Mac does **not** play on the Mac. They grab their phone
  like everyone else. There is deliberately **no local controller** on macOS;
  keeping Mac and TV feature-identical beats a half-baked Mac controller.
- It shows an **AirPlay button** that mirrors the board (the same screen the TV
  renders natively) to another display, so the Mac can drive a big screen it is
  not physically plugged into.
- On tvOS there is no mirror button — the board *is* the TV's output.

Same QR, same room code, same join flow, same rules either way.

## Screens (canonical copy)

### Mobile — menu entry
```
MULTIPLAYER
Scan the QR code on the Apple TV to join a game.
[ SCAN QR ]   [ ENTER ROOM CODE ]
```
If a scanned deep link already opened the app, skip this screen and go
straight to the join flow.

### Mobile — join
```
ARE YOU STUPID?
You're playing on: Living Room TV
PLAYER NAME
[ MASSIMO________ ]
[ JOIN ]
Waiting for host…
```
After joining:
```
✓ JOINED
MASSIMO
Waiting for the other players…
```
The player always sees: player count, their own name, ready state
(`PLAYER_READY_ROSTER` from the host, [[Multiplayer Protocol]]).

### TV — lobby
```
ARE YOU STUPID?     SCAN TO JOIN
        [ QR CODE ]
        ROOM 7F4K
PLAYERS
✓ MASSIMO        ✓ SAMI
✓ LUCA           ○ GIULIA
4 PLAYERS          [ START GAME ]
```
- START GAME is enabled only when **≥2 players** are ready.
- Up to **8 players**.
- The host can remove a disconnected player (roster edit).

## Avatars (no assets)

Auto-generated per player: a colored circle + the player's first initial,
optionally an emoji the player picks (persisted per profile, [[Multiplayer
Client (Mobile)]]). Same palette as the app theme ([[Rendering Pipeline]]).

## Room codes, security, joining

- Code = 4 characters from an unambiguous set (no `I`/`O`/`0`/`1`), random,
  e.g. `7F4K`. Enough entropy for casual collision avoidance.
- The QR encodes `areyoustupid://join?room=7F4K`. Generating the QR is
  on-device (`CIQRCodeGenerator`, zero assets — [[Multiplayer Host (tvOS)]]).
- A room lives only while the host app runs. Nothing sensitive is ever on the
  wire ([[Multiplayer Protocol]]).
- Manual `ENTER ROOM CODE` is a fallback; users never type long codes.

## Disconnect handling

- Transient player drop: grace window (15s default) → rejoin with same player
  identity restores state ([[Multiplayer Architecture]]).
- Host quits: board room gone, mobile shows `HOST_DISCONNECTED`; MVP ends the
  match, no host migration ([[Decision Log]]).

## Ads

**Never during a live multiplayer match.** A controller NEVER shows an ad
mid-round — the local party experience is uninterrupted
([[Multiplayer Client (Mobile)]] callout, carried into [[Monetization and
Ads]] policy). Ads may appear only:
- when returning to the main menu,
- before starting a new match,
- after a match ends.

Rewarded ads, when offered, may unlock **cosmetic/bonus** perks for the winner
(or the whole group) — never a competitive gameplay advantage; ads must not
make the multiplayer game unfair.

## Sharing

At the end of a match the TV shows:
```
WINNER
SAMI
LEVEL 42
CAN YOU BEAT US?
```
Mobile players can share a result: a generated text line and a
**screenshot-style result card** rendered on-device (no assets —
[[Rendering Pipeline]] visual language), e.g.:

> We played Are You Stupid? on Apple TV. Sami won. Think you can beat us?

Goes through the OS share sheet (`share_plus`) exactly like the single-player
share flow ([[Virality and Sharing]]); no account, no tracking.

## Local data

- **Mobile (persisted):** player name, preferred emoji, multiplayer statistics
  (matches, wins, best finish), settings — via `SharedPreferences`
  ([[State and Persistence]], [[Multiplayer Client (Mobile)]]).
- **Board (TV or macOS host):** basic settings + optional local match stats
  (`UserDefaults`).
- No cloud storage.

## Explicitly out of scope (MVP)

- Online matchmaking, accounts, cloud saves, global leaderboards.
- Voice/video chat, complex player profiles, cosmetics marketplace.
- Anything requiring a backend or internet connection to play.

## Success criteria

Done when, on a real LAN: launch the host (Apple TV **or macOS board-only**)
→ see QR → scan with iPhone → app opens and joins → name appears on the board
→ second player joins → START GAME → **identical** challenge on both phones →
independent answers → results on the board → multiple rounds → eliminations →
winner → immediate rematch. Must feel like a polished party game, not a demo.

## Related

- [[Multiplayer Architecture]] — host authority & topology
- [[Multiplayer Protocol]] — the wire contract behind joining/play
- [[Multiplayer Host (tvOS)]] — the TV side
- [[Multiplayer Client (Mobile)]] — the phone side
- [[Multiplayer Gameplay]] — modes, rounds, TV presentation
- [[Monetization and Ads]] — the single-player ad policy this extends
- [[Virality and Sharing]] — the single-player share flow this mirrors