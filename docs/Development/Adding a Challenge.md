---
tags: [development, howto, challenges]
updated: 2026-10-03
---

# Adding a Challenge

The most common task in this repo. Target: **one new class + one registry line.**

## 1. Pick the family file

`lib/challenges/` — `color_`, `word_`, `counting_`, `patience_`,
`memory_`, `perception_`, `trick_`. New family? New file.

## 2. Write it

Simplest case — reuse `TapTargetChallenge`:

```dart
/// TAP THE LIAR.
TapTargetChallenge buildLiar(ChallengeParams p) {
  final colors = p.shuffled(kBasicColors);
  final targets = honestColorTargets(colors, p.locale);
  return TapTargetChallenge(
    p,
    id: 'liar',
    tag: ChallengeTag.word,
    duration: p.pace(const Duration(milliseconds: 2600), floorMs: 1200),
    instruction: p.tr('challenge.liar.instruction'),
    targets: targets,
    correctIds: {targets.first.id},
    wrongReason: p.tr('challenge.liar.wrong'),   // always ship a fail line
  );
}
```

Needs its own timeline or state? Extend `BaseChallenge` and implement
`onTick` / `onTap` / `onTimeout`, mutating `instruction`, `targets`, `hint`,
`bigCenterText`, `blackout`, `pressure`, then call `host.invalidate()`.

Rules:
- Instruction **under 8 words**, uppercase.
- Judge on `TapKind.down` (`TapKind.up` only for holds).
- Always scale timing with `p.pace(base, floorMs: ...)`; never hardcode a raw
  duration unless the challenge *is* about absolute time.
- Never import Flutter. See [[Challenge System]].
- Never hardcode English text in the challenge file — every `instruction`,
  `hint`, `wrongReason`/`lateReason` and success `note` goes through
  `p.tr('challenge.<id>.<field>', {args})`, with the key added to **all six**
  `lib/i18n/strings_*.dart` files. See [[Localization]].

## 3. Register it

`lib/challenges/registry.dart`:

```dart
ChallengeTemplate(
  id: 'liar',
  tag: ChallengeTag.word,
  build: buildLiar,
  minLevel: 9,     // mean templates start late
  weight: 0.8,     // rare if it is nasty
),
```

`starter: true` only for challenges that are genuinely trivial and fair.

## 4. Test it

`test/challenge_templates_test.dart` covers your template automatically
(builds on every level band, resolves on timeout, instruction length, unique
target ids). Add the *specific* behaviour to
`test/challenge_behaviour_test.dart`: the winning input, the losing input, and
the trap. See [[Testing]].

## 5. Translate it

Add every new key to **all six** `lib/i18n/strings_*.dart` files (English is
the source of truth; the other five must define the same keys — see
[[Localization]]). If the challenge's gameplay content *is* words (a decoy
list, an antonym pair, a letter count) it needs a hand-authored equivalent per
language, not a literal translation — [[Localization]] explains why and shows
the existing examples.

## 6. Add the iMessage counterpart — mandatory

Stupid Streak does **not** execute Dart inside the Messages extension. Every
new or changed challenge must therefore be mirrored deliberately in the pure
Swift generator under
`ios/iMessageExtensionCore/Sources/AYSMessageCore/StupidChallenge.swift`:

- preserve the same player-facing mechanic, correct answer and one-line fail
  explanation;
- derive every random choice from the supplied seeded `SplitMix64`; never use
  `Int.random`, `arc4random` or wall-clock state;
- keep the instruction uppercase and under eight words;
- place it in the appropriate Stupid Streak difficulty pool rather than making
  it available in every round;
- extend `MessageCoreTests` so identical `{matchSeed, round, streak}` inputs
  prove identical Swift output.

The Dart and Swift implementations do not need byte-identical view models —
the two products have different renderers — but they must represent the same
recognisable challenge and remain deterministic within their own match.

If a mechanic genuinely cannot work inside the iMessage extension (for
example, it requires an API or interaction unavailable to an extension), do
not invent a degraded substitute silently. Record the exception and reason in
[[iMessage Multiplayer]], append [[Decision Log]], and mark the catalog row as
`Exception`. Mere implementation effort is not an exception.

Verify the native side:

```bash
swift test --package-path ios/iMessageExtensionCore
xcodebuild -project ios/Runner.xcodeproj -target StupidStreak \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

## 7. Document it — mandatory

Add a row to [[Challenge Catalog]] in the **same commit**, including its
`iMessage` parity status (`Mirrored` or a documented `Exception`). See
[[Documentation Rules]].

## Checklist

- [ ] Instruction under 8 words
- [ ] Own fail line
- [ ] `minLevel` / `weight` set honestly
- [ ] Behaviour test (win + lose + trap)
- [ ] Every string added to all six `lib/i18n/strings_*.dart` files
- [ ] Swift iMessage counterpart added/updated and determinism tested
- [ ] Or: genuine iMessage exception documented in [[iMessage Multiplayer]]
      and [[Decision Log]]
- [ ] Row in [[Challenge Catalog]] with iMessage parity status
- [ ] `swift test --package-path ios/iMessageExtensionCore` green
- [ ] `StupidStreak` simulator target builds
- [ ] `flutter analyze` clean, `flutter test` green
