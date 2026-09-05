---
tags: [development, howto, challenges]
updated: 2026-09-05
---

# Adding a Challenge

The most common task in this repo. Target: **one new class + one registry line.**

## 1. Pick the family file

`lib/challenges/` — `color_`, `word_`, `counting_`, `patience_`,
`memory_`, `perception_`, `trick_`. New family? New file.

## 2. Write it

Simplest case — reuse `TapTargetChallenge`:

```dart
/// TAP THE ONE THAT IS LYING.
TapTargetChallenge buildLiar(ChallengeParams p) {
  final colors = p.shuffled(kBasicColors);
  final targets = honestColorTargets(colors);
  return TapTargetChallenge(
    p,
    id: 'liar',
    tag: ChallengeTag.word,
    duration: p.pace(const Duration(milliseconds: 2600), floorMs: 1200),
    instruction: 'TAP THE LIAR',
    targets: targets,
    correctIds: {targets.first.id},
    wrongReason: 'THAT ONE WAS HONEST.',   // always ship a fail line
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

## 5. Document it — mandatory

Add a row to [[Challenge Catalog]] in the **same commit**. See
[[Documentation Rules]].

## Checklist

- [ ] Instruction under 8 words
- [ ] Own fail line
- [ ] `minLevel` / `weight` set honestly
- [ ] Behaviour test (win + lose + trap)
- [ ] Row in [[Challenge Catalog]]
- [ ] `flutter analyze` clean, `flutter test` green
