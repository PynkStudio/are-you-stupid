---
tags: [ai, architecture, foundationmodels]
updated: 2026-09-11
---

# Dynamic Profiles and Tool Calling

How the model is configured per job and what real data it may read. Both
concepts are **bounded by the same vocabulary discipline** as challenges:
closed categories, validated output, never the raw player history.

**Implementation status:** `ChallengeGenerationProfile` is real
(`ios/Runner/AppleAIService/ChallengeGenerationProfile.swift`), with its
three tools (`GetPlayerProfileTool`, `GetRecentChallengesTool`,
`GetAvailableMechanicsTool`) implemented in `GenerationTools.swift` — but
**backed by a Dart-computed snapshot sent up front with the request, not a
live bidirectional bridge** as this note's "call back into Dart" framing
implies. For a single one-shot `requestChallenge` call, everything these
tools return was already available before the model session even starts,
so building a genuine reverse-channel callback (novel, and unverifiable
without a real device) wasn't worth it — see the 2026-09-11
[[Decision Log]] entry. `CommentaryProfile`/`FinalRoundProfile`/
`MultiplayerHostProfile` and their own tool sets (`GetCurrentScoresTool`,
`GetRoundHistoryTool`, `ValidateChallengeTool`) aren't built — no caller
needs them yet.

## Profiles

A profile bundles the system prompt, the `GenerationOptions` and the tool set
for one Director job — the Swift side has one function per profile
(`requestChallenge`, `requestCommentary`, …; see
[[Foundation Models Integration]] → method table).

| Profile | Worker | Prompt job | Temperature | Tools |
|---|---|---|---|---|
| `ChallengeGenerationProfile` | challenge writer | invent a `ChallengeProposal` from a `PlayerProfile` + territory | 0.9 | GetPlayerProfileTool, GetRecentChallengesTool, GetAvailableMechanicsTool |
| `CommentaryProfile` | one-liner | one line for exactly one `kind` | 0.9 | GetPlayerProfileTool, GetRecentChallengesTool |
| `FinalRoundProfile` | pressure-writer | final-round challenge leaning on *this player's* data | 0.2 | GetPlayerProfileTool, GetCurrentGameStateTool, GetRecentChallengesTool |
| `MultiplayerHostProfile` | party host | one round for a room (stats + a theme) | 0.6 | GetCurrentScoresTool, GetAvailableMechanicsTool, GetRecentChallengesTool |

Prompts are **English system prompts, compiled into the binary** (no remote
configuration — see [[Feature Flags]]). The player's language never flows into
v1 generation ([[Localization and Language]]).

## Tools

Real reads from the running game state (Dart side owns the truth; the Swift
tools call back into Dart through a small tool bridge). Each tool has a
`@Generable` argument/return struct ([[Foundation Models Integration]]) and a
**hard output cap**. The model may call tools during a generation; tool errors
surface as `ToolCallError` and abort that unit (→ scripted fallback).

| Tool | What it returns | Bounds |
|---|---|---|
| `GetPlayerProfileTool` | the **truncation facade** of `ayu.profile` — only `mostCommonMistakeCategory`, per-mechanic success rates rounded to 10 %, `averageReactionTimeMs`, `fastestStreak` | nothing identifying; no names; no raw events |
| `GetRecentChallengesTool` | last 4 `{ challengeId, mechanic }` pairs | ids + mechanic only |
| `GetAvailableMechanicsTool` | mechanics whose `minLevel <= level` (and trick-enabled variants if `allowTricks`) | mirrors the registry |
| `GetCurrentGameStateTool` | `{ level, streak, bestLevel, locale }` | in-memory only |
| `GetRoundHistoryTool` | per-round `{ challengeId, outcome, reactionMs, mistakeCategory? }` for the **current session only**, capped at 10 entries | the model sees recent rounds *within the round*, not the whole profile |
| `ValidateChallengeTool` | lets the model self-check its proposal against the [[AI Challenge Validator]] envelope rules | returns the verdict; does **not** substitute the real validator — the Dart side always re-validates |
| `GetCurrentScoresTool` | multiplayer `{ eliminations, scoresByPlayerRole(no names) }` | anonymous roles |

**Design rule that keeps telemetry honest:** tools return *aggregates and
enums*, never free-form transcripts or the raw telemetry log. Combine that with
[[Player Telemetry and Adaptive Difficulty]]'s "structure over free text / the
model proposes, the validator disposes" rule and the flood surface for
"model learned the player's private history" is structurally closed, not just
discouraged.

## Guardrails tied to profiles

- **One unit = one profile.** No tool is reachable from a profile that
  doesn't list it (the Swift session is built per-profile with exactly that
  tool array).
- `GetRoundHistoryTool` and `GetCurrentScoresTool` are **session-scoped and
  anonymous**; nothing in them can be correlated with a person.
- Temperature per profile is part of the schema contract — the profile that
  must be *precise* (`FinalRoundProfile`) is the profile least allowed to
  improvise.

## Related

- [[Foundation Models Integration]] — `@Generable` arg/return structs
- [[AI Challenge Generation]] — the proposal this profile-building feeds
- [[Player Telemetry and Adaptive Difficulty]] — the profile facade
- [[Multiplayer AI Director]] — MultiplayerHostProfile on the wire
- [[Privacy and Offline]] — why the facade, not the raw log