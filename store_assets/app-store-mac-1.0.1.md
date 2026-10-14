# Mac App Store — macOS 1.0.1 (build 11), en-US

## What's new

Your Mac is now the whole game: play solo with a single click, or host the party board for up to 16 players. No ads on Mac.

## Promotional text (≤170)

Play solo on your Mac — or turn it into the party board: everyone gets the same stupid instruction, the screen shows who blew it. Up to 16 players.

## Description

ARE YOU STUPID?! is the game where every instruction is stupidly simple — and you will still get it wrong. On the Mac, play it solo, or turn your Mac into the game board of a party for the whole room.

You had ONE job.

PLAY SOLO
• Tap the color. Don't tap anything. Wait for green. Remember the number. Every instruction is under 8 words — and the trap is always right there.
• Fail and you'll know exactly why, in one line. Retry in under a second.
• Levels get stupider as you climb. Beat your best level, then beat it again.
• Play with the mouse or trackpad. No account, no internet, no ads on the Mac.

OR HOST THE PARTY
• Choose MULTIPLAYER > HOST ON THIS MAC: a game board opens with a room code and a QR code. Send it to the TV with AirPlay, or just gather around the Mac.
• Everyone joins from their phone with the Are You Stupid?! iPhone app, on the same Wi-Fi. Phones become the controllers, the Mac shows the instruction, who got it right, who didn't, and the live scoreboard.
• 2 to 8 players, up to 16 with the Party Pack.
• Two modes: Stupid Battle (everyone plays to the end, most points wins) and Last Stupid Standing (fail and you lose a life; last one left wins).

OR JOIN ONE
• Choose MULTIPLAYER > PLAY ON THIS MAC to join a party hosted on an Apple TV or another Mac nearby.

PRIVATE BY DESIGN
No account, no sign-up, no analytics. Everything happens on your devices and your local network.

One purchase works everywhere: the Party Pack bought on iPhone, iPad or Mac is shared with your Mac, Apple TV and iPhone through the same App Store account (and with Family Sharing).

## Review notes

No account or login: the game has none.

This Mac app is the full game. Two ways to test it:

1. SINGLE PLAYER: launch the app and click PLAY. Follow the instruction on screen (e.g. "TAP RED"); a wrong click or running out of time ends the run with a one-line explanation. TRY AGAIN restarts; CONTINUE resumes once per run (free on Mac — the Mac build shows no ads).

2. PARTY MODE (needs an iPhone with the iOS app from this same App Store record, on the same Wi-Fi):
   a. On the Mac: MULTIPLAYER > HOST ON THIS MAC. A board window opens with a room code and a QR code.
   b. On the iPhone: scan the QR with the Camera app (it is a universal link, https://pynkstudio.eu/ays/join?room=XXXX, that opens the app in the room), or open the app > MULTIPLAYER > ENTER ROOM CODE.
   c. Join with a name and tap READY on two phones (or one phone plus PLAY ON THIS MAC on a second Mac), then start the game from the board.
   MULTIPLAYER > PLAY ON THIS MAC joins a room hosted by an Apple TV or another Mac (pick it from the nearby list or type its code); the Mac has no camera QR scanner.

In-app purchases (non-consumable, restorable in SETTINGS > RESTORE PURCHASE): Party Pack (ays_party_pack, raises the room limit from 8 to 16). The Mac does not offer Remove Ads or the Party Bundle because the Mac build shows no ads; owned purchases from other devices appear as owned.

WHY com.apple.security.network.server: in HOST ON THIS MAC the Mac is the server of the local game. It creates a TCP listener (Network framework, NWListener) and advertises it via Bonjour as _ays-party._tcp; the iPhones discover it and connect to it, and the Mac accepts those incoming connections and drives the rounds. Without this entitlement the App Sandbox blocks the listener and no phone can join. com.apple.security.network.client is used by PLAY ON THIS MAC to connect to a host on the local network. No data leaves the local network.
