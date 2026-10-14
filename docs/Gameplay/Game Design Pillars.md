---
tags: [design, pillars]
updated: 2026-10-12
---

# Game Design Pillars

## The joke

The player must always think *"this is fucking easy"* — and then fail on something
stupid. The game makes them question whether **they** are the problem.

The target reaction after losing is **not** "this game sucks", it is
**"I know what I did wrong. Let me try again."**

Everything in this repo is judged against that sentence.

## Hard rules

0. **The name is ARE YOU STUPID?! — always with "?!".** In every version,
   every screen, every platform and every language: home title, Game Over
   header, share text, host board, window and menu titles, the device
   display name (`CFBundleDisplayName`, `android:label`) and store art.
   Translations are fine (MA SEI SCEMO?!, ¡¿ERES ESTÚPIDO?!, ES-TU STUPIDE ?!,
   BIST DU DUMM?!, VOCÊ É BURRO?!) but the "?!" never goes. The device name
   stays English, matching the App Store name. See [[Decision Log]].
1. **Fair, not random.** Every failure must be explainable in one sentence by the
   player. If a challenge cannot be understood *after* losing, it is a bad
   challenge. See [[Challenge Catalog]].
2. **Under 8 words** per instruction. Enforced by a test in [[Testing]].
   One owner-approved exception: AI-generated challenges in a non-English
   language may use up to 10 words and get +1–2 s to read them
   ([[Localization and Language]]). Scripted instructions keep the rule in
   every language.
3. **Zero downtime.** Correct answer → 240 ms green flash → next challenge.
   Mistake → 2.85 s red flash with the roast (long enough to actually read
   it — tap it to skip straight to Game Over if you already know why you
   lost) → Game Over. No loading, no route changes.
4. **One hand, one thumb.** Everything is a tap or a hold. No swipes, no
   multi-touch, no precision dragging.
5. **Offline first.** Single-player needs no account, network or backend.
   Multiplayer core play is also LAN-local and offline-capable; its optional
   [[Multiplayer Presenter]] may use an online cache/TTS backend but can only
   enrich the show. Ads also need a round trip. Neither service may gate play,
   and no ad-gated action may be offered when no ad is available. See
   [[State and Persistence]] and [[Monetization and Ads]].
6. **No external visual assets.** Visuals are generated from native widgets,
   shapes, gradients and text. Audio is the deliberate exception: a tiny,
   reviewed ElevenLabs-generated SFX bank ships for semantic feedback in both
   runtimes, fixed at 32% linear playback gain; the presenter also has its
   versioned voice pack ([[Multiplayer Presenter]]). The bank stays small,
   offline and source-controlled so core play never waits on generation.
7. **9:16 first.** The screen must read well in a vertical screen recording —
   large type, huge targets, strong color states. See [[Virality and Sharing]].
8. **Words never break; headlines are balanced.** Every title and big
   headline renders through `BalancedText`: a word is never split across
   lines (it shrinks instead), and multi-word headlines wrap into even lines
   (`CONGRATULATIONS, / I GUESS`, never `CONGRATULATIONS, I / GUESS`). Six
   locales have very different word lengths; this keeps every screen
   symmetric without hand-placed line breaks. See [[Rendering Pipeline]].

## Session shape

- One run = 20 s to 2 min.
- A challenge = 1–5 s.
- Score = the level you reached. Nothing else is a score.
- Restart = one tap, under a second (the Game Over screen is a layer on the game
  screen, not a route).

## Where difficulty comes from

Not reflexes alone. In order of importance:
misleading wording → changing rules → ambiguous instructions → fake buttons →
visual distraction → memory → timing → raw speed.

See [[Difficulty Curve]].
