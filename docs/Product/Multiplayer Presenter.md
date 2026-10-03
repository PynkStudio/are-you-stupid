---
tags: [product, multiplayer, audio, ai, presenter]
updated: 2026-10-03
---

# Multiplayer Presenter

The multiplayer board may use an **optional online voice presenter**: a
charismatic game-show host who speaks during safe comedy beats, reacts to real
match facts and develops running jokes about the players. It is a show layer,
not game authority. A match remains fully playable when internet, AI or speech
generation is unavailable ([[Multiplayer Architecture]]).

## Character and timing

The host is elegant, theatrical and increasingly disappointed by the room. It
teases demonstrated play, never bodies, identity or protected traits. Good
slots are lobby waiting, results, eliminations, standings changes and game end;
silence is preferable to commentary every round.

Lines stay short and subtitle verbatim. Highlighting the target card makes
`MA CE LA FAI?` unambiguous without a name. Voice has a separate toggle.

## Cache-first voice ladder

The presenter resolves every cue through this ladder without delaying play:

1. Bundled fallback clip for essential/common beats.
2. Host disk cache.
3. Shared backend/CDN cache.
4. New online text-to-speech generation.
5. Subtitle only if audio is not ready before the cue's deadline.

The host chooses event, line/template and variant; the backend only resolves
or produces audio. Gameplay never waits for it.

Three content tiers keep cost and latency bounded:

- **Universal:** no player data (`lobbyEmpty`, `everyoneWrong`, `finalStart`).
  Curated variants are synthesized once, cached permanently and ship in the
  tvOS/macOS host bundle as a versioned presenter pack.
- **Templated:** approved copy with a spoken-name slot (`{player} is out`).
  Only the audio combination is generated; common combinations are reusable.
- **Dynamic:** a newly written line for a rare, specific match story. Reserve
  this for moments where a template cannot carry the joke.

Target mix: roughly 75–85% universal, 10–20% templated and under 5% fully
dynamic. Prefetch likely branches during a round and named cues on join. Never
expose a provider key in the app: a minimal backend authenticates rooms,
rate-limits spend, calls speech and returns audio. It owns no game state.

Remote cache identity includes the exact filtered spoken text, voice/model
version, locale and delivery style. It deliberately excludes the cue ID, so
the same rendered phrase for `Luca` is reused across compatible events instead
of being synthesized twice. The backend stores only a SHA-256 cache key,
object path, counters/timestamps and MP3 — not the name or sentence as database
columns. Each hit advances `last_accessed_at`; a daily cleanup removes audio
and metadata unused for 30 days. Common names/phrases therefore remain warm,
while rare combinations disappear automatically. Bundled universal audio is
still permanent and versioned with the app.

The bundled presenter pack and its text manifest are released in lockstep with
the host app. Every bundled clip has the same stable line ID used by backend
and subtitles, so online and offline selection cannot drift. A later app
release may refresh the pack; runtime downloads are an optimization, never the
only copy of baseline commentary.

## Cue deadlines and late delivery

Every cue declares a relevance policy; connectivity never changes game timing:

| Cue | If audio misses its ideal slot |
|---|---|
| Lobby ambience | Play later only while the same lobby state remains true |
| Round-result joke | Discard when the result screen closes |
| Elimination | Allow through its elimination beat; discard before next round |
| New title/rivalry | Defer to the next safe beat if the underlying fact remains true |
| Winner/game-end verdict | Play late while the final screen is still active |

The subtitle follows the same policy: do not show a generated line at a time
when its audio would be stale. A cue may be delayed for theatrical timing, but
must never refer to an old leader, eliminated target or superseded title.

## Display name versus spoken identity

Joining creates separate values:

```text
displayName: x_$Luca🔥_xX
spokenName: Luca
speechPolicy: speakAlias
```

Deterministic normalization runs first: normalize Unicode, remove invisible
characters and edge decoration, collapse spaces, and retain a conservative
set of letters, apostrophes and hyphens. It also rejects contact details,
URLs, obvious profanity and prompt-like payloads. If the result is clear, no
model call is needed.

When available, the on-device model may classify an ambiguous name and extract
a pronounceable alias using a closed structured result:

```text
decision: speakOriginal | speakAlias | displayOnly | blocked | uncertain
spokenName: optional short value
confidence: 0..1
```

The model is advisory, never the only safety layer: Android and unsupported
Apple devices must behave correctly without it. Low confidence becomes
`displayOnly`. If an alias differs materially, joining shows `THE HOST WILL
CALL YOU: LUCA` and lets the player reject or edit it. Manual pronunciation
passes through the same validator.

The phone caches the verified result against the exact display name. A later
join with the same spelling reuses `spokenName` and `speechPolicy`; changing
even one character invalidates that association and runs classification again.
The cache currently stores the deterministic classifier's verdict and is also
the persistence seam for the future on-device-model verdict.

Only the validated spoken alias may leave the phone for speech generation;
the decorated raw name does not. Unpronounceable or unsafe names remain
visible when otherwise acceptable, while audio uses direct second-person copy.
Truly abusive display names may be blocked. Names are data fields, never
interpolated into model instructions.

## Homonyms are a joke, not an error

The room detects collisions after spoken-name normalization. It may assign
room-local narrative labels such as `L'ALTRO LUCA`, `IL VERO LUCA` or, for a
third collision, a deliberately exasperated variation. Visual color/emoji and
the highlighted card preserve clarity even when the spoken label is comically
ambiguous. Critical state such as elimination and winner is always explicit on
screen.

## Narrative titles

An in-match story ledger holds deterministic match tags per player; AI or
curated rules may turn compatible tags into a title:

```text
winStreak4 + fastest3       -> THE KING / THE UNBEATABLE
threeEarlyFailures         -> THE ONE WHO DOESN'T READ
largeComeback              -> THE REDEEMED
sameSpokenNameCollision    -> THE OTHER LUCA
```

Titles are introduced before repeated use, can escalate, and must be revoked
or inverted when the story changes. This creates arcs: `THE UNBEATABLE` can
become `THE FORMERLY UNBEATABLE`; `THE BAD LUCA` can earn a comeback line.
The model may phrase a fact but may not invent one. At game end, the board may
promote an earned title into a small local career record keyed by the phone's
anonymous `personaId`. When that persona later joins the same board, the host
can say `È TORNATO IL KING INDISCUSSO`. Positive titles live for 90 days;
negative titles live for only 7 so a joke cannot become a permanent label.
The board retains at most 64 careers. This memory is device-local, has no
account or cloud sync, and the identifier contains no name.

Player references resolve in this order: current narrative title when earned,
homonym label when needed, validated spoken name, then direct anonymous copy.
Negative titles describe observed performance only. Stronger labels such as
`THE BAD LUCA` require the room's spicy/Savage setting; neutral mode uses
gentler failure titles. All output still passes the commentary length, tone,
dedupe and forbidden-topic validation in [[AI Commentary]].

Savage narration should approach the permitted boundary rather than becoming
nominally spicy: it may be pointed, persistent, personalized and callback-heavy
about what the player demonstrably did. The hard ceiling never moves: no slurs,
protected traits, appearance/body, sexuality, health, disability, family,
trauma, threats, real-world allegations or degrading a person's human worth.
The joke may say `THE WORST LUCA IN THIS ROOM`; it may not explain that result
through anything outside the match. Uncertain output is rejected, not softened
after synthesis.

## Failure, privacy and accessibility contract

- Local LAN play, judging, score and winner never depend on the backend.
- A missed audio deadline falls through immediately; no spinner or stalled
  transition is allowed.
- The exact spoken line is always captioned; narration has its own toggle and
  volume. Reduce Motion does not remove the visual target highlight.
- Send the minimum event facts and validated alias. Do not upload raw names,
  transcripts, contacts, persistent identifiers or gameplay history to the
  speech backend. The anonymous `personaId` stays on the LAN between phone and
  board and keys only the board's local career store.
- Log operational IDs/latency/cache outcome, not line text or player identity.
- Generated text is validated before TTS; generated audio never becomes an
  input to game rules.

## Implementation boundary

The host needs a cue coordinator, disk cache, audio player and backend client.
Mobile owns name classification and sends its speech policy/alias through a
future additive protocol change ([[Multiplayer Protocol]]). The backend needs
ephemeral room authorization, cache/TTS, retention and spend controls. Provider
selection follows a voice bake-off for performance, pronunciation, latency,
licensing and price.

**Implementation status:** the pure Swift cue engine, versioned text manifest,
semantic expiry, title ledger, local returning-player careers, homonym labels, host disk/backend
ladder and AVFoundation playback are wired. Flutter performs deterministic
spoken-name extraction and sends `spokenName`/`speechPolicy` on join. The
shared PynkStudio/Menuary backend now contains `/api/ays/presenter`, backed by
OpenAI speech plus a private Supabase cache and sliding 30-day retention cron.
Still required before production:
deploy/apply the storage migration, provision host/backend tokens and URL,
choose the licensed voice, populate the bundled `PresenterPack` MP3s, add the
AI refinement/confirmation UI for ambiguous names, and expose presenter intensity/toggles in
host settings. Until the pack/config exists, the host uses system TTS as a
development-only offline safety net.
