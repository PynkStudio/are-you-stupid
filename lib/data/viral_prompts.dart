import 'dart:math';

/// Occasional nudges to challenge a friend. Shown rarely on purpose.
class ViralPrompts {
  ViralPrompts._();

  static const lines = <String>[
    'CAN YOU BEAT YOUR FRIEND?',
    "SEND THIS TO SOMEONE WHO THINKS THEY'RE SMART.",
    "YOUR FRIEND PROBABLY WON'T PASS LEVEL 20.",
    'MOST PEOPLE DIE AT LEVEL 14.',
    'SCREENSHOT THIS. FLEX LATER.',
    'SOMEONE OUT THERE IS ON LEVEL 40.',
  ];

  static final _rng = Random();

  static String random([Random? rng]) {
    final r = rng ?? _rng;
    return lines[r.nextInt(lines.length)];
  }
}
