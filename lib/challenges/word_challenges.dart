import '../core/challenge.dart';
import 'base.dart';

/// 8 — TAP THE ONE THAT SAYS "DON'T TAP".
TapTargetChallenge buildTapWordButton(ChallengeParams p) {
  const decoys = ['TAP', 'TAP ME', 'NOT THIS', 'MAYBE', 'NO', 'YES', 'HERE'];
  final words = [
    "DON'T TAP",
    ...p.shuffled(decoys).take(3),
  ];
  final shuffled = p.shuffled(words);
  final targets = wordTargets(shuffled);
  return TapTargetChallenge(
    p,
    id: 'tap_word_button',
    tag: ChallengeTag.word,
    duration: p.pace(const Duration(milliseconds: 3000), floorMs: 1300),
    instruction: 'TAP THE ONE THAT SAYS "DON\'T TAP"',
    targets: targets,
    correctIds: {targets[shuffled.indexOf("DON'T TAP")].id},
    wrongReason: 'JUST READ.',
  );
}

/// 9 — TAP NOTHING. There is, of course, a button labelled NOTHING.
TapTargetChallenge buildTapNothingButton(ChallengeParams p) {
  final words = p.shuffled(['NOTHING', 'SOMETHING', 'ANYTHING', 'EVERYTHING']);
  final targets = wordTargets(words);
  return TapTargetChallenge(
    p,
    id: 'tap_nothing_button',
    tag: ChallengeTag.trick,
    duration: p.pace(const Duration(milliseconds: 2600), floorMs: 1200),
    instruction: 'TAP NOTHING',
    targets: targets,
    correctIds: {targets[words.indexOf('NOTHING')].id},
    wrongReason: 'IT WAS LITERALLY THERE.',
    lateReason: 'IT WAS LITERALLY THERE.',
  );
}

/// 10 — TAP THE ODD ONE OUT. Three colors and a sandwich.
TapTargetChallenge buildOddWordOut(ChallengeParams p) {
  const intruders = ['PIZZA', 'CHAIR', 'BANANA', 'MONDAY', 'SOCKS', 'CLOUD'];
  final colors = p.shuffled(kBasicColors).take(3).map((c) => c.label).toList();
  final intruder = p.pick(intruders);
  final words = p.shuffled([...colors, intruder]);
  final targets = wordTargets(words);
  return TapTargetChallenge(
    p,
    id: 'odd_word_out',
    tag: ChallengeTag.word,
    duration: p.pace(const Duration(milliseconds: 2800), floorMs: 1200),
    instruction: 'TAP THE ODD ONE OUT',
    targets: targets,
    correctIds: {targets[words.indexOf(intruder)].id},
  );
}

/// 11 — TAP THE OPPOSITE OF LEFT.
TapTargetChallenge buildOpposite(ChallengeParams p) {
  const pairs = [
    ['LEFT', 'RIGHT'],
    ['UP', 'DOWN'],
    ['YES', 'NO'],
    ['STOP', 'GO'],
    ['BIG', 'SMALL'],
    ['HOT', 'COLD'],
  ];
  final pair = p.pick(pairs);
  final asked = p.pick(pair);
  final answer = pair.first == asked ? pair.last : pair.first;
  final words = p.shuffled(pair);
  final targets = wordTargets(words);
  return TapTargetChallenge(
    p,
    id: 'opposite',
    tag: ChallengeTag.word,
    duration: p.pace(const Duration(milliseconds: 2300), floorMs: 1100),
    instruction: 'TAP THE OPPOSITE OF $asked',
    targets: targets,
    correctIds: {targets[words.indexOf(answer)].id},
    layout: ChallengeLayout.row,
    wrongReason: 'OPPOSITE. THE OTHER ONE.',
  );
}

/// 12 — TAP THE NUMBER OF LETTERS IN "SEVEN".
TapTargetChallenge buildSpellCount(ChallengeParams p) {
  const words = {
    'ONE': 3,
    'TWO': 3,
    'FOUR': 4,
    'FIVE': 4,
    'SEVEN': 5,
    'EIGHT': 5,
    'THREE': 5,
    'TWELVE': 6,
  };
  const digits = {
    'ONE': 1,
    'TWO': 2,
    'FOUR': 4,
    'FIVE': 5,
    'SEVEN': 7,
    'EIGHT': 8,
    'THREE': 3,
    'TWELVE': 12,
  };
  final word = p.pick(words.keys.toList());
  final answer = words[word]!;
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
    duration: p.pace(const Duration(milliseconds: 3600), floorMs: 1600),
    instruction: 'TAP THE LETTERS IN "$word"',
    hint: 'HOW MANY LETTERS',
    targets: targets,
    correctIds: {'n$answer'},
    wrongReason: 'COUNT. THE. LETTERS.',
  );
}
