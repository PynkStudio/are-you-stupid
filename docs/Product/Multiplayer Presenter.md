---
tags: [product, multiplayer, audio, ai, presenter]
updated: 2026-10-17
---

# Multiplayer Presenter

The multiplayer board may use an **optional online voice presenter**: a
charismatic game-show host who speaks during safe comedy beats, reacts to real
match facts and develops running jokes about the players. It is a show layer,
not game authority. A match remains fully playable when internet, AI or speech
generation is unavailable ([[Multiplayer Architecture]]).

## Character and timing

The host is elegant, theatrical and increasingly disappointed by the room,
but it is not polite family-TV banter. The target room is a loud group of
friends already roasting one another; the presenter earns its place by
raising that energy. It attacks demonstrated play, confidence, hesitation,
rank and rivalry, never bodies, identity or protected traits. Good slots are
lobby waiting, results, eliminations, standings changes and game end; silence
is preferable to commentary every round.

`NEUTRAL` stays concise and amused, with enough bite to avoid sounding like a
scripted television host. `SAVAGE` is a genuine roast, not neutral copy with a
slightly harsher adjective. Vary its attack:

- **Plateale:** direct public humiliation after an obvious failure.
- **Indirect:** calm praise whose implication makes the insult land a beat
  later.
- **Rivalry:** use another player's success to sharpen the target's loss.
- **Callback:** reuse a player's earlier confidence or repeated mistake.
- **Fake broadcast:** invoke the control room, audience, adjudicator or a
  familiar quiz-show convention as if the room were a collapsing live show.
- **Mechanic-aware:** name how elementary the failed action was: one button,
  a tiny sum, counting, reading, waiting or remembering a single item.

The strongest lines state an observable fact, then expose why it is
embarrassing: “Io mi vergognerei a perdere contro `{name}`” or “`{name}` era
convinto. È questo l'aspetto più grave.” Avoid generic insults that could be
played after any event, empty cruelty and elegant aphorisms detached from the
room. The joke must feel improvised from what just happened.

Broadcast references deliberately break the fourth wall and may be culturally
specific. Locales adapt the underlying device to a locally familiar quiz-show
convention; they do not translate named references literally. Prefer generic
roles and conventions over celebrity impersonation, endorsement or a copied
catchphrase.

Mechanic-aware lines bind to a specific challenge family or failure reason and
must never fire on an unrelated round. They should expose the smallest literal
task the player failed (“Non pensavo servisse un tutorial per premere un
bottone”) rather than explain the challenge rules. This copy is metadata on
the presenter cue, not part of the challenge's instructional or fail-line
contract.

Lines stay short and subtitle verbatim. Highlighting the target card makes
`MA CE LA FAI?` unambiguous without a name. Voice has a separate toggle.

## Cache-first voice ladder

The presenter resolves every cue through this ladder without delaying play:

1. Pack clip: synced from the backend or bundled with the app.
2. Host disk cache of generated lines.
3. Shared backend cache.
4. New online text-to-speech generation.
5. Subtitle only if audio is not ready before the cue's deadline. Release
   builds never fall back to the device's system speech: a second, robotic
   voice breaks the character worse than silence. Debug builds keep it as a
   development aid.

The host chooses event, line/template and variant; the backend only resolves
or produces audio. Gameplay never waits for it.

The room presenter supports the same six locales as the game: English,
Italian, French, Spanish, Portuguese and German. On launch the board derives
the presenter's locale from the host device language and falls back to English
when it is unsupported. Language is deliberately a secondary lobby action:
`OPTIONS` opens the presenter panel, where the host can override the locale,
choose output independently as `OFF`, `MUTE` or `VOICE`, and choose
`NEUTRAL` or `SAVAGE` intensity whenever output is not Off. `OFF` suppresses
both speech and the matching presenter caption; `MUTE` keeps the caption but
never starts pack playback, cache lookup or TTS. Both settings persist and
neither disables unrelated AI Director copy.

Three content tiers keep cost and latency bounded:

- **Universal:** no player data (`lobbyEmpty`, `everyoneWrong`, `finalStart`).
  Curated variants are synthesized once, cached permanently and ship in the
  tvOS/macOS host bundle as a versioned presenter pack.
- **Templated:** approved copy with a spoken-name slot (`{player} is out`).
  Only the audio combination is generated; common combinations are reusable.
- **Dynamic:** a newly written line for a rare, specific match story. Reserve
  this for moments where a template cannot carry the joke.

Target mix: roughly 75–85% universal, 10–20% templated and under 5% fully
dynamic. Prefetch likely branches during a round and named cues on join.
At every `ROUND_START` the board asks the engine for the named lines the
result could need (`PresenterEngine.likelyNamedLines`: imminent titles first,
then each player's most likely roast round-robin, rendered exactly as they
would be spoken and without spending them) and warms the host disk cache
with at most 8 backend calls per round, skipping lines already on disk. That
stays under the backend's 30 speech calls per minute per board. Mute and Off
never prefetch. Never
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

## Remote presenter pack

Universal lines, spoken-name templates and narrative title wording live in a
**line book** published by the PynkStudio backend, so copy and recordings can
change without an app release:

- Source: one `content/ays-presenter/pack.<locale>.json` per supported locale
  in the PynkStudio repo (`en`, `it`, `fr`, `es`, `pt`, `de`).
  `npm run ays:pack` validates it (uppercase, ≤ 180 characters, only known
  templates/placeholders), records only new or changed lines, uploads them
  to the private `ays-presenter-pack` bucket and publishes the manifest as a
  new revision.
- Host: `PresenterPackStore` fetches `GET /api/ays/presenter/pack` (ETag →
  `304` when unchanged) at hosting start and at each match start, at most
  every 15 minutes. It downloads every missing clip from
  `/api/ays/presenter/pack/clips/<sha256>`, verifies size and SHA-256, and
  only then swaps the manifest. A half-downloaded pack is never used.
- **Replace** a recording: change its text or bump its `take`. The clip is
  content-addressed, so the new audio gets a new hash and cannot be confused
  with the old one.
- **Invalidate** a line: remove it from the JSON and publish. Boards drop it,
  and delete its file, on their next sync. `--prune` also removes unused
  clips from the bucket.
- A new book applies immediately in the lobby, otherwise at the next match
  start: copy never changes mid-match.

The release bundle carries all six published packs
(`scripts/fetch_presenter_pack.sh` → `tvos/TVResources/PresenterPack/`), and
the code keeps a localized text-only baseline (`PresenterLineBook.builtIn(locale:)`). The board
uses whichever of the synced and bundled packs has the higher revision.
Runtime downloads remain an optimization, never the only copy of baseline
commentary.

### What the server can and cannot change

The server changes **what is said**; the app still decides **when**, from
facts it has verified. For every beat the engine asks the book for a list of
keys, most specific first, and plays the first one that has lines:

| Beat | Keys (most specific → generic) |
|---|---|
| Round result | `<outcome>.streak3`, `result.mixed.oneWrong` / `result.mixed.oneCorrect`, `<outcome>.mechanic.<category>`, `<outcome>.firstRound`, `<outcome>` |
| Named Savage result | `result.mixed.oneWrong.mechanic.<category>`, late first point, still zero after 3+ rounds, or wrong streak 3+, then its generic named key |
| Lobby | `lobby.empty` |
| Game end, no name | `gameEnd` |

`<outcome>` is `result.everyoneWrong`, `result.everyoneCorrect` or
`result.mixed`. Publishing lines under a narrower key covers that case with
no app release. A case built on a **new fact** (for example "the same player
failed in two different modes") still requires app code to emit a new key.
Mechanic categories are the fixed
vocabulary `button`, `math`, `counting`, `reading`, `waiting`, `timing`,
`memory`, `direction` and `perception`; every one of the 39 shipped challenge
ids maps to exactly one category. `HostViewModel` retains the verified
`ROUND_START.challengeId` by round id until `ROUND_RESULTS`, so no protocol
field or client-reported description is trusted for this copy.

Templates the app can fill: `title.named`, `title.anonymous`,
`gameEnd.named` (`{name}`), `result.player.again` (`{name}`, the repeat
callback), `lobby.returning.named`,
`lobby.returning.anonymous` (`{title}`, plus `{name}` where named). Title
wording: `king`, `kingUndisputed`, `doesNotRead`. Any line may be restricted
to `neutral` or `savage` intensity. Unknown keys, bad placeholders or
lowercase copy are rejected by the publish script and dropped again by the
host. A manifest `format` newer than the build understands is ignored
entirely.

## Voice provider

One backend module (`src/lib/ays-presenter/speech.ts`) owns synthesis, so
pack clips and live lines come from the same voice. **ElevenLabs** is the
default whenever `ELEVENLABS_API_KEY` and `AYS_PRESENTER_ELEVENLABS_VOICE_ID`
are set: `eleven_v3` for the pre-recorded pack (most expressive, latency
irrelevant) and `eleven_flash_v2_5` for live named lines. The host waits
for live audio as long as the cue is still relevant (8 s ceiling), not a
fixed short timeout: a cache miss measured ~2.2 s end to end on 2026-10-17,
which is why a fixed 1.4 s timeout made about every other named line fall
through to the robotic system voice. Otherwise the backend falls back to OpenAI `gpt-4o-mini-tts`.
The selected production voice is **AYS — The Disappointed Host**
(`C5m0ozw0kWxM7oU5fgRY`), a generated multilingual voice. Its character
background is an elegant former European prime-time announcer now condemned
to host the simplest competition imaginable: warm baritone, measured pace,
crisp diction, controlled delivery and growing disappointment. Neutral lines
use restrained sarcasm; Savage lines may escalate into a pointed roast while
remaining controlled rather than frantic. The background guides identity; individual v3 lines may still use
sparingly chosen delivery tags to shape a specific performance. Production
pack synthesis uses the approved consistency preset: seed `42817`, stability
`0.42`, similarity boost `0.86`, style `0.42`, speaker boost enabled and speed
`1.03`. Keep the same seed and settings across a locale's takes; unusually low
stability is rejected because it changes the apparent speaker and pacing.

Lobby copy is direct and situational: the host addresses the actual
contestants with theatrical impatience, rather than delivering abstract
one-liners. Approved Italian examples include “Ma davvero questo è il meglio
che abbiamo stasera?”, “Ma vuoi chiudere Instagram ed entrare in partita, o
no?” and “Se questi sono i concorrenti, io me ne vado.” Other locales should
adapt the comic intent and spoken rhythm, not translate these literally.
Subtitles stay uppercase; the selected locale is sent on every live request,
selects the corresponding debug-only system voice (`en-US`, `it-IT`, `fr-FR`,
`es-ES`, `pt-PT`, `de-DE`) and separates manifest, ETag and generated-audio
caches. The backend sends sentence-case text to the
voice, because all-caps input is read as shouting or spelled out. The voice
tag (provider, voice, model) is part of every cache key: changing voice
regenerates audio instead of mixing voices. Pack clips change only on the
next publish.

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
Relevance is checked until playback begins. If the next round starts while a
line is still loading, that line is discarded; if its audio has already
started, it is allowed to finish naturally across the round boundary.

One beat emits at most one presenter cue. When a result also awards a title,
the line book may provide one combined sentence containing both facts. If no
combined template exists, the title wins the slot; two independent voice
tracks are never started together.

## Display name versus spoken identity

Joining creates separate values:

```text
displayName: x_$Luca🔥_xX
spokenName: Luca
speechPolicy: speakAlias
```

Deterministic normalization runs first: normalize Unicode, fold common
leetspeak (`0→o`, `1/!→i`, `3→e`, `4/@→a`, `5/$→s`, `7→t`, etc.), remove invisible
characters and edge decoration, collapse spaces, and retain a conservative
set of letters, apostrophes and hyphens. Gamer-tag "x" wrappers are
dropped only when clearly decorative — a 2–3 run on both sides (`xXLucaXx`)
or a run set apart by a space/underscore (`x_Luca_x`); a bare edge x is part
of the name (ALEX, MAX, FELIX, XAVIER). It also rejects contact details,
URLs, obvious profanity and prompt-like payloads. If the result is clear, no
model call is needed.

When available, the on-device model classifies an ambiguous name and extracts
a pronounceable alias using a closed structured result:

```text
decision: speakOriginal | speakAlias | displayOnly | blocked | uncertain
spokenName: optional short value
confidence: 0..1
```

Name analysis never blocks entry: an ambiguous player joins provisionally as
`displayOnly` and the lobby shows that the presenter is still trying to read
the name. If that phone has no model, it sends a two-second LAN request through the host
to the highest-ranked AI-capable phone already in the room. The host routes the
answer only to the requester; the helper phone never displays the name. If no
answer arrives, joining continues as `displayOnly`.

The model is advisory, never the only safety layer: Android and unsupported
Apple devices still behave correctly without it. Low confidence becomes
`displayOnly`. If an alias differs materially, joining shows `THE HOST WILL
CALL YOU: LUCA`; display-only and blocked names show explicit warnings, with
the latter using the game's `NICE TRY` voice. The lobby warning opens `COME TI
CHIAMERÀ?`, where the player can inspect or change name/pronunciation without
leaving the room. A completed verdict updates the live roster additively.

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

## Repetition guard

Playtests showed the presenter repeating itself: similar situations produced
the same or near-identical comments within one match, because only universal
lines had any memory (the last 4 ids) and per-player templates rotated with
none. Every cue now passes one guard (`PresenterLineHistory`):

- **Memory by joke, not by id.** A line is remembered by its normalized words
  (letters and digits, name and punctuation stripped) **and**, for
  multi-sentence lines, by its final sentence — the punch. Two lines with
  different ids but the same words, or a new setup with the same punch
  (`ABBIAMO UN VINCITORE. TECNICAMENTE.` / `{name} HA VINTO. TECNICAMENTE.`),
  count as one joke.
- **Cooldown in beats.** A joke may not return for 6 beats — round results,
  lobby and game-end moments, whether or not the host spoke at them — and the
  clock runs across rematches.
- **Named jokes once per match.** Templated per-player lines are spent for
  the rest of the match once told, whoever they were aimed at.
  `beginMatch()` clears that, not the cooldown.
- **Ladder instead of repeat.** A spent specific line falls through to the
  next key of the specificity ladder or the next matching fact; a player
  already roasted this match first gets the escalating callback
  `result.player.again` (`ANCORA TU, {name}? ORMAI È UN APPUNTAMENTO FISSO.`,
  three Savage variants per locale) before the engine moves on.
- **Silence beats a repeat.** When every candidate is cooling down or spent,
  the beat emits no cue. With today's 2–3 published variants per generic
  outcome, a long run of identical outcomes therefore goes quiet between
  lines, matching "silence is preferable to commentary every round" above.
- The in-code baseline still fills a key only when the active book has
  nothing for the beat, so a line removed from the published book stays
  removed.

Variety now scales with the line book: publishing more variants per key (and
`result.player.again` copy, once the publish script's allowlist knows the key)
directly buys more distinct lines per match. AI-generated fresh variants of a
spent beat remain future work.

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

**Implementation status:** the pure Swift cue engine, data-driven line book
with specificity ladder, semantic expiry, title ledger (reset per match),
local returning-player careers, homonym labels, pack sync, host
disk/backend ladder and AVFoundation playback are wired. Flutter performs
deterministic spoken-name extraction and sends `spokenName`/`speechPolicy`
on join. The backend on `https://pynkstudio.eu` serves live speech
(`POST /api/ays/presenter`, private cache with sliding 30-day retention) and
the pack (`GET /api/ays/presenter/pack`, `…/pack/clips/<sha256>`). The
shared token is set on Vercel production and in the untracked
`tvos/Config/Presenter.secrets.xcconfig`, which tvOS and the Mac Runner
both read. As of 2026-10-11, the multilingual backend is deployed and revision
1 is published for `en`, `it`, `fr`, `es`, `pt` and `de`: 11 permanent
ElevenLabs `eleven_v3` clips per locale plus the localized named/result
templates. All six manifests and 66 content-addressed clips are also bundled
under `tvos/TVResources/PresenterPack/`; first launch still syncs a newer
revision when one exists. Local/LAN AI name
refinement and join-form pronunciation warnings are wired. Language, output
`OFF`/`MUTE`/`VOICE` and independent `NEUTRAL`/`SAVAGE` controls already ship
in host Options. The token ships inside the host binary,
so it is a speed bump, not authentication. Per-room ephemeral authorization
and a spend ceiling remain open. System TTS remains only the final
development/offline safety net.
Blocked or deliberately evasive names receive one of five localized,
presenter-voiced UI rebukes instead of a generic validation error. The choice
is deterministically derived from the normalized name, so it varies between
players but never flickers while the same player edits or reopens the name
card. These lines are screen copy only: a blocked name is never sent to TTS.
