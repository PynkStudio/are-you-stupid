---
tags: [product, multiplayer, party]
updated: 2026-10-06
---

# Multiplayer Product

The party-mode product concept and scope for **ARE YOU STUPID?** — a
controller-led party game, building on the design pillars in
[[Game Design Pillars]] without breaking them.

## Concept

The tagline stays **YOU HAD ONE JOB.**

The party mode is for a group sitting in front of a shared screen:

- The **board is the game master** ([[Multiplayer Host (tvOS)]]) — an Apple TV,
  or a **Mac** running the same ARE YOU STUPID? app with HOST ON THIS MAC (the
  board window is host + display only; see below).
- Each player uses their **own iPhone/iPad as a controller**
  ([[Multiplayer Client (Mobile)]]).
- Everyone receives the **same challenge simultaneously**
  ([[Multiplayer Challenges]]).
- The challenges are intentionally simple, but layer in misleading
  instructions, timing traps, visual tricks and psychological mistakes.
- The fun is **watching friends fail.**

## Player experience (2-16 players; 8 free)

1. Open ARE YOU STUPID? on Apple TV **(or on your Mac: MULTIPLAYER → HOST ON
   THIS MAC opens the board, and you play on your phone like everyone else)**.
2. The board creates a local room, advertises it on the LAN, and shows a QR code.
3. Opening Multiplayer on a phone automatically suggests nearby rooms with the
   host device name and live occupancy; QR and room code remain fallbacks.
4. The player joins the room ({NAME} + optional emoji), name appears on the board.
5. Everyone presses READY; the host starts when ≥2 are ready.
6. The same challenge appears on every connected device.
7. Players answer independently; the board shows live results and rankings.
8. Players are eliminated ([[Multiplayer Gameplay|Last Stupid Standing]]) or
   accumulate points ([[Multiplayer Gameplay|Stupid Battle]]).
9. The last player standing / highest scorer wins.
10. Instantly rematch or return to menu.

No account is required. Core room play remains local and works without
internet. The optional online [[Multiplayer Presenter]] may add generated
voice commentary; losing it only removes narration, never the match.

## macOS: one app, host or play

There is a single Mac app — the same ARE YOU STUPID? the player already knows.
MULTIPLAYER on the Mac asks **WHAT ARE YOU DOING?**:

- **PLAY ON THIS MAC** joins a room as a controller, exactly like a phone.
- **HOST ON THIS MAC** opens the board in its own window. That board runs the
  **exact same host core and screens as tvOS**, so groups without an Apple TV
  can host from any Mac. The board window is **board-only**: it hosts,
  displays and owns the rules; it is not itself a controller. Keeping Mac and
  TV boards feature-identical beats a half-baked hybrid.
- It shows an **AirPlay button** that mirrors the board (the same screen the TV
  renders natively) to another display, so the Mac can drive a big screen it is
  not physically plugged into.
- On tvOS there is no mirror button — the board *is* the TV's output.

Same QR, same room code, same join flow, same rules either way.

## Screens (canonical copy)

### Mobile — menu entry
```
MULTIPLAYER
[ APPLE TV — LIVING ROOM       3/8 PLAYERS   JOIN ]
[ SCAN QR ]   [ ENTER ROOM CODE ]
```
Nearby rooms update while this screen is visible. A match already in progress
stays visible as `IN PROGRESS` but cannot accept a new player. Discovery stops
when the app leaves the foreground. The advertised name is the host's local
device name — LAN-only metadata, never sent outside the home network.
If a scanned deep link already opened the app, skip this screen and go
straight to the join flow.

First visit only, before any system prompt — the permissions primer:
```
QUICK THING FIRST
To play on the TV, this phone needs:
LOCAL NETWORK — to find the TV on your Wi-Fi. Nothing leaves your home.
CAMERA (OPTIONAL) — only to scan the QR code. You can type the code instead.
Your phone will ask. Tap Allow. It is not a trick question.
[ CONTINUE ]   [ NOT NOW ]
```
If Local Network access is denied or later revoked, the menu entry (and the
join screen, when a room can't be found) shows:
```
Local network access is off. Without it this phone can't find the TV.
[ OPEN SETTINGS ]
```
If the permission is available but the phone is not using Wi-Fi, the empty
nearby-room state is replaced immediately with the localized roast: **"NO
WI-FI. THE TV ISN'T TELEPATHIC. JOIN ITS NETWORK."** The join failure uses the
same specific explanation. Only a phone already on Wi-Fi gets the generic
"room not found" result; this keeps a missing host distinct from a missing
network without reading or displaying the SSID.
Details in [[Multiplayer Client (Mobile)]] "Permissions".

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
- Up to **8 players** in every free room; **16** when any joined phone owns
  Party Pack. One owner unlocks the whole room for that room session.
- The host can remove a disconnected player (roster edit).

## Avatars (no assets)

Auto-generated per player: a colored circle + the player's first initial,
optionally an emoji the player picks (persisted per profile, [[Multiplayer
Client (Mobile)]]). Same palette as the app theme ([[Rendering Pipeline]]).

## Room codes, security, joining

- Code = 4 characters from an unambiguous set (no `I`/`O`/`0`/`1`), random,
  e.g. `7F4K`. Enough entropy for casual collision avoidance.
- The QR encodes the universal link `https://pynkstudio.eu/ays/join?room=7F4K` (any camera can open it; see [[Multiplayer Protocol]]). Generating the QR is
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

**Never during a live multiplayer match.** After `GAME_END`, a player may tap
RIVINCITA. If nobody in the room owns Remove Ads or Party Bundle, that requesting
phone alone receives one interstitial; the board and every other phone show a
short synchronized troll break. Dismissal, no-fill or offline immediately
returns everyone to the same lobby. If any joined player owns either no-ads product,
the whole room skips the break. No timer or automatic placement exists.

During the break, non-requesting phones may show the explicit Remove Ads CTA.
The board never loads an ad: tvOS/macOS only render the joke/status screen.

Rewarded ads, when offered, may unlock **cosmetic/bonus** perks for the winner
(or the whole group) — never a competitive gameplay advantage; ads must not
make the multiplayer game unfair.

## Party Pack

`ays_party_pack` is a non-consumable upgrade that only raises a room from 8 to
16 seats. `ays_party_bundle` raises the cap and also removes ads. Either
capacity entitlement activates as soon as its owner joins or completes the
purchase in the lobby. The room benefit is sticky until the host room closes;
the buyer leaving or being eliminated never shrinks a live party.

At 8/8 every joined phone shows **SBLOCCA 16 GIOCATORI** and states that one
purchase unlocks everyone. Party Pack and Party Bundle are offered side by
side in that lobby banner and in Settings. A blocked ninth join receives the same purchase
prompt and the host broadcasts `PARTY_PACK_NUDGE`, making existing phones'
banner shake/haptic. Activation makes the board and phones celebrate with
generated pomp. A dedicated activation sound is intentionally deferred until
the later multiplayer sound-design pass; the UI must not claim it exists yet.

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
  (matches, wins, best finish), settings, anonymous presenter persona and the
  last exact-name pronunciation verdict — via `SharedPreferences`
  ([[State and Persistence]], [[Multiplayer Client (Mobile)]]).
- **Board (TV or macOS host):** basic settings, optional local match stats and
  a bounded/expiring narrative-career cache keyed by anonymous persona
  (`UserDefaults`).
- No cloud storage.

## Optional online show layer (post-MVP)

Multiplayer deliberately differs from the offline-only single-player product:
it may use a minimal backend for the cache-first [[Multiplayer Presenter]].
The board and phones still own the room over LAN. Online services may generate
or retrieve narration but never judge input, score players or gate play.

## Browser host (demand-gated, not prioritized)

A web page that replaces the Apple TV/macOS board remains a possible future
accessibility expansion for groups without Apple hardware. It is **not current
roadmap work and not a promised platform**. Re-evaluate it only when either:

- the game has a meaningful sustained average-user base that justifies an
  always-available room service; or
- user feedback repeatedly identifies the Apple-only host as a real barrier
  to starting multiplayer sessions.

The browser cannot directly reproduce the shipped host topology: web pages
cannot listen for raw TCP clients or advertise a Bonjour service. The most
practical production shape would therefore be a WebSocket room backend, with
both the browser board and mobile controllers connecting to it. That would add
hosting, privacy, abuse prevention and operational responsibilities and would
make web-hosted matches internet-dependent, while the Apple TV/macOS path
would remain the local/offline option. This architecture is only a recorded
direction for later evaluation; no web-host implementation or backend scope is
approved today.

## Explicitly out of scope (MVP)

- Online matchmaking, accounts, cloud saves, global leaderboards.
- Voice/video chat, complex player profiles, cosmetics marketplace.
- Anything requiring a backend or internet connection **to play or finish a
  match**. Optional show-layer enrichment may use one with local fallbacks.

The demand-gated browser host above is a possible future exception to this MVP
boundary, not part of the exception today.

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
- [[Multiplayer Presenter]] — optional voiced game-show host
- [[Monetization and Ads]] — the single-player ad policy this extends
- [[Virality and Sharing]] — the single-player share flow this mirrors
