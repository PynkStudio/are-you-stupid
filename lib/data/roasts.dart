import 'dart:math';

/// Short lines shown after a mistake. Mix of playful roasts and neutral ones —
/// the game teases, it never actually bullies.
class Roasts {
  Roasts._();

  static const spicy = <String>[
    'YOU HAD ONE JOB.',
    'BRUH.',
    'REALLY?',
    'THINK.',
    'HOW?',
    'BRO.',
    'COME ON.',
    'THAT WAS EMBARRASSING.',
    'MY GRANDMA GOT FURTHER.',
    'THE INSTRUCTIONS WERE RIGHT THERE.',
    "YOU'RE MAKING THIS HARDER THAN IT IS.",
    'JUST READ.',
    'YOU ACTUALLY DID THAT.',
    'CONGRATULATIONS, I GUESS.',
    'IMPRESSIVE.',
    '💀',
  ];

  static const neutral = <String>[
    'NOPE.',
    'WRONG.',
    'NOT QUITE.',
    'CLOSE.',
    'THAT WAS EASY.',
    'ALMOST.',
    'AGAIN?',
    'HMM.',
    'OOF.',
    'TRY AGAIN.',
  ];

  static const late = <String>[
    'TOO SLOW.',
    'TIME.',
    'YOU FROZE.',
    'ASLEEP?',
  ];

  static const praise = <String>[
    'OK.',
    'FINE.',
    'NOT BAD.',
    'LUCKY.',
    'SURE.',
    'GOOD.',
  ];

  static final _rng = Random();

  /// ~55% neutral so the game stays playful instead of hostile.
  /// With [allowSpicy] off (Settings), only the neutral pool is used.
  static String forMistake({Random? rng, bool allowSpicy = true}) {
    final r = rng ?? _rng;
    final pool = !allowSpicy || r.nextDouble() < 0.55 ? neutral : spicy;
    return pool[r.nextInt(pool.length)];
  }

  static String gameOver({Random? rng, bool allowSpicy = true}) {
    final r = rng ?? _rng;
    final pool = !allowSpicy || r.nextDouble() < 0.5 ? neutral : spicy;
    return pool[r.nextInt(pool.length)];
  }

  static String pick(List<String> pool, [Random? rng]) {
    final r = rng ?? _rng;
    return pool[r.nextInt(pool.length)];
  }
}
