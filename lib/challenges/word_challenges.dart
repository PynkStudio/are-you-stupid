import '../core/challenge.dart';
import 'base.dart';

/// 8 — TAP THE ONE THAT SAYS "DON'T TAP". The decoys and the target word are
/// re-authored per language in `lib/i18n/strings_*.dart`
/// (`word.tap_word_button.*`) — not translated word-for-word, since the
/// point is a plausible-looking set of short button labels.
TapTargetChallenge buildTapWordButton(ChallengeParams p) {
  final target = p.wordButtonTarget;
  final words = [
    target,
    ...p.shuffled(p.wordButtonDecoys).take(3),
  ];
  final shuffled = p.shuffled(words);
  final targets = wordTargets(shuffled);
  return TapTargetChallenge(
    p,
    id: 'tap_word_button',
    tag: ChallengeTag.word,
    duration: p.pace(const Duration(milliseconds: 3000), floorMs: 1300),
    instruction: p.tr(
      'challenge.tap_word_button.instruction',
      {'word': target},
    ),
    targets: targets,
    correctIds: {targets[shuffled.indexOf(target)].id},
    wrongReason: p.tr('challenge.tap_word_button.wrong'),
  );
}

/// 9 — TAP NOTHING. There is, of course, a button labelled NOTHING. The
/// quartet (`word.tap_nothing_button.*`) is re-authored per language; index 0
/// is always the correct answer.
TapTargetChallenge buildTapNothingButton(ChallengeParams p) {
  final correctWord = p.nothingWords[0];
  final words = p.shuffled(p.nothingWords);
  final targets = wordTargets(words);
  return TapTargetChallenge(
    p,
    id: 'tap_nothing_button',
    tag: ChallengeTag.trick,
    duration: p.pace(const Duration(milliseconds: 2600), floorMs: 1200),
    instruction: p.tr(
      'challenge.tap_nothing_button.instruction',
      {'word': correctWord},
    ),
    targets: targets,
    correctIds: {targets[words.indexOf(correctWord)].id},
    wrongReason: p.tr('challenge.tap_nothing_button.wrong'),
    lateReason: p.tr('challenge.tap_nothing_button.wrong'),
  );
}

/// 10 — TAP THE ODD ONE OUT. Three colors and a sandwich.
TapTargetChallenge buildOddWordOut(ChallengeParams p) {
  final colors =
      p.shuffled(kBasicColors).take(3).map((c) => p.colorLabel(c)).toList();
  final intruder = p.pick(p.oddWordIntruders);
  final words = p.shuffled([...colors, intruder]);
  final targets = wordTargets(words);
  return TapTargetChallenge(
    p,
    id: 'odd_word_out',
    tag: ChallengeTag.word,
    duration: p.pace(const Duration(milliseconds: 2800), floorMs: 1200),
    instruction: p.tr('challenge.odd_word_out.instruction'),
    targets: targets,
    correctIds: {targets[words.indexOf(intruder)].id},
  );
}

/// 11 — TAP THE OPPOSITE OF LEFT.
TapTargetChallenge buildOpposite(ChallengeParams p) {
  final chosen = p.pick(p.oppositePairs);
  final pair = [chosen.$1, chosen.$2];
  final asked = p.pick(pair);
  final answer = pair.first == asked ? pair.last : pair.first;
  final words = p.shuffled(pair);
  final targets = wordTargets(words);
  return TapTargetChallenge(
    p,
    id: 'opposite',
    tag: ChallengeTag.word,
    // A beat of semantic recall, not just a glance-and-tap.
    duration: p.pace(const Duration(milliseconds: 2700), floorMs: 1350),
    instruction: p.tr('challenge.opposite.instruction', {'word': asked}),
    targets: targets,
    correctIds: {targets[words.indexOf(answer)].id},
    layout: ChallengeLayout.row,
    wrongReason: p.tr('challenge.opposite.wrong'),
  );
}

/// 12 — TAP THE NUMBER OF LETTERS IN "SEVEN". The answer (letter count) and
/// the trap (the number the word names) are computed per language in
/// `lib/i18n/spell_count_data.dart` — translating the English words while
/// keeping their letter counts would give the wrong answer.
TapTargetChallenge buildSpellCount(ChallengeParams p) {
  final letters = p.spellCountLetters;
  final digits = p.spellCountDigits;
  final word = p.pick(letters.keys.toList());
  final answer = letters[word]!;
  final trap = digits[word]!;
  final options = <int>{answer, trap};
  while (options.length < 4) {
    options.add(2 + p.rng.nextInt(9));
  }
  final list = p.shuffled(options.toList());
  final targets = numberTargets(list);
  return TapTargetChallenge(
    p,
    id: 'spell_count',
    tag: ChallengeTag.word,
    // Reading, then literally counting letters — the heaviest word trick.
    duration: p.pace(const Duration(milliseconds: 4200), floorMs: 1900),
    instruction: p.tr('challenge.spell_count.instruction', {'word': word}),
    hint: p.tr('challenge.spell_count.hint'),
    targets: targets,
    correctIds: {'n$answer'},
    wrongReason: p.tr('challenge.spell_count.wrong'),
  );
}
