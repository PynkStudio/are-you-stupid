---
tags: [product, multiplayer, imessage, ios]
updated: 2026-10-17
---

# iMessage Multiplayer

**Stupid Streak** is the small asynchronous 1v1 edition of ARE YOU STUPID?!
inside Messages. It is deliberately separate from the live Apple TV/Mac party
mode in [[Multiplayer Product]]: there is no room, host, account, matchmaking,
commentary, backend or simultaneous connection.

## Match flow

1. The first player starts from the iMessage app and plays round 1.
2. The extension inserts an interactive message into the conversation.
3. The second player taps it and plays the exact same seeded sequence. The
   first streak is hidden in normal UI until this attempt ends.
4. The result message reveals the round and lets the first player start the
   next one.
5. Three rounds produce a final best-of-three score and a rematch action.

The sender must tap Messages' Send button after the extension inserts each
update. This is an asynchronous conversation game, not background networking.
It is intended for a one-to-one iMessage conversation; group-chat identity and
spectator rules are not part of v1.

## Rules

- A player's round score is the number of consecutive challenges completed
  before the first mistake or timeout.
- Higher streak wins the round.
- Equal streaks use total correct-answer time as the tie-break. A difference
  of 40 ms or less is a tie rather than pretending device timing is exact.
- The match is best of three. An overall draw is allowed; v1 has no sudden
  death because another message round would make the supposedly tiny mode
  sprawl.
- Both players receive the same match seed, round index and streak index, so
  challenge kind, content, ordering and timing are deterministic.
- The first player's result is encoded in the message state but not displayed
  before the reply. This is social fairness, not tamper-proof competition;
  the no-backend design has no server authority or anti-cheat claim.

## Difficulty

Difficulty grows disproportionately across the three rounds:

| Round | Opening pool | Escalation |
|---|---|---|
| 1 | direct color/number choices | a harder family enters every three wins |
| 2 | mixed arithmetic/perception | shorter timer and trick families earlier |
| 3 | already deceptive | fastest timer compression and advanced pool |

The native subset contains ten generated families, each a port of an app
template: tap color (`tap_color`), don't tap color (`dont_tap_color`), tap
number, arithmetic, odd-one-out, opposite (`opposite`), biggest dot, do
nothing (`dont_tap`), wait-for-green and left/right swap (`left_right_swap`).
Instructions remain uppercase and under eight words in every language; every
failure has one explanatory line, preserving [[Game Design Pillars]]. Correct
and wrong flashes use 240 ms / 850 ms beats.

Variety rules (2026-10-17, `StupidChallengeGenerator`):

- A round is generated in order, so each pick sees the previous two: **the
  same family never appears twice in a row**, and not the one from two steps
  back while the pool has another option. Round 1 opens on five starter
  families instead of two.
- Color and number buttons are reshuffled every challenge, so even a repeated
  family never repeats its layout.
- **"Opposite" always names its word** (`TAP THE OPPOSITE OF LEFT`, using the
  app's six opposite pairs). It never refers back to a previous challenge, so
  it cannot appear "out of context".
- Left/right is the app's swap mechanic: two coloured blocks change places
  mid-challenge and the named *screen side* is the answer. (The old version
  put the words on the wrong sides and its fail line contradicted the answer.)
- The correct flash replaces the instruction with `✓ <streak>` so a pass is
  visibly registered even when the next instruction looks similar.

### Catalog parity contract

The extension does not import or execute `lib/challenges/`; its Swift subset is
therefore **not automatically synchronized** with the Flutter registry. To
prevent future drift, adding or changing an app challenge now includes a
mandatory Swift counterpart and deterministic Swift test in the same change.
The exact procedure and completion checklist live in [[Adding a Challenge]].

A challenge may skip iMessage only when the Messages extension cannot support
the mechanic without changing what makes it fair or funny. That exception must
be named here, marked in [[Challenge Catalog]], and justified in [[Decision
Log]]. Cost or inconvenience alone is not a valid exception. The current 30
unported pre-existing templates are legacy backlog, not 30 approved
exceptions; the rule applies prospectively to every new or modified template.

#### Approved exceptions

None.

## Architecture

`ios/iMessageExtension/` is a native UIKit Messages extension whose principal
controller is `MessagesViewController`. Flutter is intentionally not embedded
in the extension process: its short lifecycle and constrained surface do not
justify loading a second Flutter engine.

Pure Swift state and deterministic generation live in
`ios/iMessageExtensionCore/` and build both as extension sources and as a
standalone Swift package for headless tests. `MessageMatch` is JSON encoded,
base64url wrapped and stored in `MSMessage.url`; `MSSession` replaces the prior
interactive message with each turn. Protocol version 1 rejects malformed or
future state instead of attempting a partial match.

The message URL uses `https://areyoustupid.game/imessage` as a transport-shaped
container only. The extension never requests it over the network. Total state
stays far below Messages' 5,000-character URL limit.

## Visuals and scope

Runtime screens and transcript cards are drawn from UIKit/Core Graphics — no
downloaded assets. The only raster artwork is the required iMessage icon set
in `ios/iMessageExtension/Assets.xcassets`, derived from the generated
Stupid Streak master in `ios/iMessageExtension/Artwork/`.

The App Store campaign is a separate five-panel 6.9-inch carousel generated
by `store_assets/generate_store_screenshots.py`. It presents the shipped UIKit
states in their Messages context: starting a 1v1, playing the deterministic
challenge, waiting with a hidden opponent score, the round scoreboard and the
final rematch. The copy deliberately says asynchronous 1v1/best-of-three and
never implies rooms, matchmaking or live networking.

## Language

The extension speaks the game's six languages (EN, IT, FR, ES, PT, DE) from
`MessageStrings` in `AYSMessageCore`, chosen from the **device language**
(`Locale.preferredLanguages`; anything else falls back to English) — the
extension process cannot read the app's in-app language setting. Challenge
copy reuses the app's own translations. Language never changes the seeded
sequence: both players face the same kinds, answers and timing, each in their
own language (tested). The transcript card is drawn on the sender's device, so
it is in the sender's language. The display name "Stupid Streak" stays
English, like the other device display names.

## Scoring, as the player sees it

Every screen shows the score from the viewer's side: **YOU n — n RIVAL**, plus
one row per round with both streaks and who took it (hidden until both
played). After a reply the player reads the verdict in one line — "POINT TO
YOU." / "POINT TO YOUR RIVAL." / "SAME STREAK. FASTER WINS." — and the rule
("Longest streak wins the round. Best of three.") sits on the start and
incoming screens.

The role is derived, not stored: the first player opens every round, so an
`awaitingReply` bubble is always sent by them and every resolved bubble by
the second player (`MessageMatch.viewerIsFirst`). Messages participant IDs
differ per device, so they cannot identify a player across devices. The
transcript card is identical on both phones, so it speaks as the sender:
`ME 1 – 0 YOU`, which reads correctly to whoever looks at the bubble.

Fixed 2026-10-17: the first player of rounds 2 and 3 used to replay the
previous round's sequence (the round index only advanced when the result was
recorded) while the rival played the real one — the main cause of "the same
challenges again" and of scores that did not make sense.

## Verification

```bash
swift test --package-path ios/iMessageExtensionCore
xcodebuild -project ios/Runner.xcodeproj -target StupidStreak \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

The Swift package covers URL round-tripping and size, deterministic sequences
(also across languages), no back-to-back family repeats, self-contained
opposites, complete translations with instructions under eight words, device
language selection, viewer role/perspective score, round tie-breaking and
score aggregation. A real two-device iMessage exchange
remains a release gate because a simulator build cannot prove message delivery
or the participant lifecycle.
