import 'package:flutter_test/flutter_test.dart';
import 'package:are_you_stupid/ai/challenge_validator.dart';
import 'package:are_you_stupid/ai/generated_challenge.dart';
import 'package:are_you_stupid/i18n/app_locale.dart';

Map<String, Object?> baseProposal({
  String id = 'ai.abc12',
  String move = 'tap_true_color',
  String action = 'tap',
  String kind = 'mixed',
  List<String> senseDecoys = const ['color', 'label'],
  String instruction = 'TAP THE ONLY BLUE',
  List<Map<String, Object?>>? elements,
  Map<String, Object?>? correct,
  Map<String, Object?>? difficulty,
  Map<String, String>? failLine,
  String source = 'ai',
  int seed = 1,
}) =>
    {
      'id': id,
      'mechanic': {
        'move': move,
        'action': action,
        'kind': kind,
        'sense_decoys': senseDecoys,
      },
      'instruction': instruction,
      'elements': elements ??
          [
            {
              'id': 'e1',
              'label': 'BLUE',
              'color': 'blue',
              'shape': 'circle',
              'scale': 1.0,
              'rotation': 0,
              'dx': 0,
              'dy': 0,
              'opacity': 1.0,
              'hidden': false,
            },
            {
              'id': 'e2',
              'label': 'RED',
              'color': 'green',
              'shape': 'circle',
              'scale': 1.0,
              'rotation': 0,
              'dx': 0,
              'dy': 0,
              'opacity': 1.0,
              'hidden': false,
            },
            {
              'id': 'e3',
              'label': 'BLUE',
              'color': 'yellow',
              'shape': 'circle',
              'scale': 0.8,
              'rotation': 0,
              'dx': 0,
              'dy': 0,
              'opacity': 1.0,
              'hidden': false,
            },
            {
              'id': 'e4',
              'label': 'BLUE',
              'color': 'purple',
              'shape': 'circle',
              'scale': 0.8,
              'rotation': 0,
              'dx': 0,
              'dy': 0,
              'opacity': 1.0,
              'hidden': false,
            },
          ],
      'correctAnswer': correct ??
          {
            'elementId': 'e1',
            'startsCorrect': false,
          },
      'difficulty': difficulty ??
          {
            'level': 1,
            'timeLimitMs': 2500,
            'trickType': 'none',
          },
      'failLine': failLine ?? {'en': 'THE ONLY BLUE WAS THE FIRST.'},
      'seed': seed,
      'source': source,
    };

ChallengeProposal pbp([Map<String, Object?> Function()? f]) {
  final map = f == null ? baseProposal() : f();
  return ChallengeProposal.fromJson(map);
}

const validator = ChallengeValidator();

ValidationContext ctx(
        {int level = 1,
        AppLocale locale = AppLocale.en,
        bool allowTricks = false,
        List<ServedChallengeStamp> recent = const []}) =>
    ValidationContext(
      level: level,
      locale: locale,
      allowTricks: allowTricks,
      recentServed: recent,
    );

ChallengeVerdict? verdictOf(ChallengeProposal p) => validator.validate(p, ctx());

void main() {
  group('valid baseline', () {
    test('a well-formed proposal is VerdictValid', () {
      expect(validator.validate(pbp(), ctx()), isA<VerdictValid>());
    });

    test('is deterministic across calls', () {
      final p = pbp();
      final first = validator.validate(p, ctx());
      final second = validator.validate(p, ctx());
      expect(first.runtimeType, second.runtimeType);
      expect(first, isA<VerdictValid>());
    });
  });

  group('1. envelope', () {
    test('rejects malformed ids', () {
      expect(verdictOf(pbp(() => baseProposal(id: 'ai.ABC12'))),
          isA<VerdictInvalid>());
      expect(verdictOf(pbp(() => baseProposal(id: 'ai.ab'))),
          hasReason('envelope.id'));
    });

    test('empty instruction is a retryable forced exit', () {
      expect(verdictOf(pbp(() => baseProposal(instruction: '  '))),
          isA<VerdictRetryableForcedExit>());
    });

    test('missing correct answer is invalid', () {
      final p = pbp(() => baseProposal(correct: {'elementId': '', 'startsCorrect': false}));
      expect(validator.validate(p, ctx()), hasReason('envelope.correctAnswer'));
    });

    test('non-ai source is an exit challenge (not a proposal)', () {
      expect(verdictOf(pbp(() => baseProposal(source: 'scripted'))),
          isA<VerdictExitChallenge>());
    });

    test('non-ascii bytes are rejected (no AI-ASCII embedding)', () {
      expect(
          verdictOf(pbp(
              () => baseProposal(instruction: 'TAP THE BLUE 💙'))),
          hasReason('envelope.ascii'));
      expect(
          verdictOf(pbp(() => baseProposal(failLine: {
                'en': 'CELUI EN BLEU ÉTAIT LE PREMIER.'
              }))),
          hasReason('envelope.ascii'));
    });

    test('the fail line must exist for the playing locale', () {
      expect(
          verdictOf(pbp(() => baseProposal(failLine: {'fr': 'LÀ.'}))),
          hasReason('envelope.failLine'));
    });
  });

  group('2. instruction rule', () {
    test('a 8-word instruction is a retryable forced exit', () {
      const long = 'TAP THE ONLY BLUE BUT NOT THE RED ONE';
      expect(verdictOf(pbp(() => baseProposal(instruction: long))),
          isA<VerdictRetryableForcedExit>());
    });

    test('lowercase instruction is retryable (uppercase is the law)', () {
      expect(verdictOf(pbp(() => baseProposal(instruction: 'tap the blue'))),
          isA<VerdictRetryableForcedExit>());
    });

    test('the mechanic imperative verb must appear', () {
      expect(verdictOf(pbp(() => baseProposal(instruction: 'NOT A VERB'))),
          hasReason('instruction.verb'));
    });
  });

  group('3. mechanic contract', () {
    test('an unknown mechanic move is unrenderable', () {
      expect(verdictOf(pbp(() => baseProposal(move: 'tap_the_vaporwave'))),
          isA<VerdictExitChallenge>());
    });

    test('the declared action must match the mechanic', () {
      expect(verdictOf(pbp(() => baseProposal(action: 'hold'))),
          hasReason('mechanic.action'));
    });

    test('when allowTricks is off, fake_button is rejected but swap is allowed', () {
      final fake = pbp(() => baseProposal(
          difficulty: {'level': 1, 'timeLimitMs': 2500, 'trickType': 'fake_button'}));
      expect(validator.validate(fake, ctx()), hasReason('mechanic.trickNotAllowed'));

      // swap is the gentle exception before tricks unlock (Difficulty Curve).
      final swap = pbp(() => baseProposal(
          difficulty: {'level': 1, 'timeLimitMs': 2500, 'trickType': 'swap'},
          correct: {'elementId': 'e1', 'startsCorrect': true}));
      expect(validator.validate(swap, ctx()), isA<VerdictValid>());
    });

    test('a trick this mechanic cannot compose is rejected', () {
      final p = pbp(() => baseProposal(
          difficulty: {'level': 20, 'timeLimitMs': 2500, 'trickType': 'rule_flip'}));
      // tap_true_color composes none/swap only.
      expect(validator.validate(p, ctx(allowTricks: true)),
          hasReason('mechanic.trickComposition'));
    });

    test('requiresTrick mechanics are invalid without a trick', () {
      final noTrick = pbp(() => baseProposal(
          move: 'dont_tap_odd',
          action: 'donot_tap',
          kind: 'trick',
          senseDecoys: ['shape', 'label'],
          instruction: "DON'T TAP THE ODD BLUE"));
      expect(validator.validate(noTrick, ctx(allowTricks: true)),
          hasReason('mechanic.trickRequired'));
    });

    test('requiresTrick mechanics play once trick + allowTricks are present', () {
      final p = dontTapOddProposal();
      expect(validator.validate(p, ctx(level: 8, allowTricks: true)),
          isA<VerdictValid>());
    });

    test('declared sense decoys must be real differences', () {
      // All labels identical -> "label" never differs.
      final p = pbp(() => baseProposal(elements: [
            {
              'id': 'e1',
              'label': 'BLUE',
              'color': 'blue',
              'shape': 'circle',
              'scale': 1.0,
              'rotation': 0,
              'dx': 0,
              'dy': 0,
              'opacity': 1.0,
              'hidden': false,
            },
            {
              'id': 'e2',
              'label': 'BLUE',
              'color': 'green',
              'shape': 'circle',
              'scale': 1.0,
              'rotation': 0,
              'dx': 0,
              'dy': 0,
              'opacity': 1.0,
              'hidden': false,
            },
            {
              'id': 'e3',
              'label': 'BLUE',
              'color': 'yellow',
              'shape': 'circle',
              'scale': 1.0,
              'rotation': 0,
              'dx': 0,
              'dy': 0,
              'opacity': 1.0,
              'hidden': false,
            },
          ]));
      expect(validator.validate(p, ctx()), hasReason('mechanic.senseDecoys'));
    });
  });

  group('4. element bounds', () {
    test('count must be in [2, 6]', () {
      // The mechanic contract's element window fires before the bounds gate.
      final p = pbp(() => baseProposal(elements: mutatedElement(8, id: 'extra')));
      expect(verdictOf(p), hasReason('mechanic.elements'));
    });

    test('scale outside [0.45, 2.0] is rejected', () {
      final p = pbp(() => baseProposal(elements: mutatedElement(4, scale: 3.0)));
      expect(verdictOf(p), hasReason('bounds.scale'));
    });

    test('opacity below 0.35 is rejected', () {
      final p = pbp(() => baseProposal(elements: mutatedElement(4, opacity: 0.2)));
      expect(verdictOf(p), hasReason('bounds.opacity'));
    });

    test('rotation above 0.6 rad is rejected', () {
      final p = pbp(() => baseProposal(elements: mutatedElement(4, rotation: 1.0)));
      expect(verdictOf(p), hasReason('bounds.rotation'));
    });

    test('offset beyond ±0.6 is rejected', () {
      final p = pbp(() => baseProposal(elements: mutatedElement(4, dx: 0.8)));
      expect(verdictOf(p), hasReason('bounds.offset'));
    });

    test('unknown shapes are unrenderable (no squircle here)', () {
      final p = pbp(() => baseProposal(elements: mutatedElement(4, shape: 'squircle')));
      expect(verdictOf(p), isA<VerdictExitChallenge>());
    });

    test('unknown colors are unrenderable', () {
      final p = pbp(() => baseProposal(elements: mutatedElement(4, color: 'ultraviolet')));
      expect(verdictOf(p), isA<VerdictExitChallenge>());
    });
  });

  group('5. time floor', () {
    test('below the difficulty floor is rejected', () {
      final p = pbp(() => baseProposal(difficulty: {
        'level': 1,
        'timeLimitMs': 1000, // level 1 speed -> floor 1500 for this mechanic
        'trickType': 'none',
      }));
      expect(verdictOf(p), hasReason('time.floor'));
    });

    test('above the 8000 ms cap is rejected', () {
      final p = pbp(() => baseProposal(
          difficulty: {'level': 1, 'timeLimitMs': 9500, 'trickType': 'none'}));
      expect(verdictOf(p), hasReason('time.cap'));
    });

    test('higher levels allow shorter rounds (floor scales with speed)', () {
      final p = pbp(() => baseProposal(difficulty: {
        'level': 20,
        'timeLimitMs': 900,
        'trickType': 'none',
      }));
      // speedForLevel(20)=1.714 -> floor ceil(900/1.714)=526 <= 900, so sane.
      expect(validator.validate(p, ctx(level: 20)), isA<VerdictValid>());
    });
  });

  group('6. decoy honesty', () {
    test('an identical decoy is rejected', () {
      // Append a perfect twin of e1 (only the id changes) so one decoy
      // differs from the correct element in nothing at all.
      final elements = [
        for (final e in (baseProposal()['elements'] as List))
          Map<String, Object?>.from(e as Map),
      ];
      elements.add(Map<String, Object?>.from(elements[0] as Map));
      (elements.last as Map)['id'] = 'e5';
      final p = pbp(() => baseProposal(elements: elements));
      expect(verdictOf(p), hasReason('decoy.identical'));
    });
  });

  group('7. freshness', () {
    test('a served near-duplicate is rejected', () {
      final p = pbp();
      final recent = [ServedChallengeStamp.ofProposal(p)];
      expect(validator.validate(p, ctx(recent: recent)),
          hasReason('freshness.duplicate'));
    });

    test('a different decoy layout is fresh enough', () {
      final p = pbp();
      final different = pbp(() => baseProposal(elements: mutatedElement(4, color: 'pink')));
      final recent = [ServedChallengeStamp.ofProposal(different)];
      expect(validator.validate(p, ctx(recent: recent)), isA<VerdictValid>());
    });
  });

  group('8. solution resolvability', () {
    test('a ghost correctAnswer is rejected', () {
      final p = pbp(() => baseProposal(correct: {'elementId': 'nope', 'startsCorrect': false}));
      expect(verdictOf(p), hasReason('solution.missing'));
    });

    test('a swap trick must start correct', () {
      final p = pbp(() => baseProposal(
          difficulty: {'level': 1, 'timeLimitMs': 2500, 'trickType': 'swap'},
          correct: {'elementId': 'e1', 'startsCorrect': false}));
      expect(verdictOf(p), hasReason('solution.swap'));
    });
  });

  group('9. neutrality & tone', () {
    test('an absolute ban is a failureExit', () {
      final p = pbp(() => baseProposal(failLine: {'en': 'KILL YOURSELF NOW.'}));
      expect(verdictOf(p), isA<VerdictFailureExit>());
    });

    test('meta-instructions that reference the AI are invalid (retryable)', () {
      final p = pbp(() => baseProposal(instruction: 'TAP THE MODEL ONE'));
      expect(verdictOf(p), hasReason('tone.metaAi'));
    });

    test('ordinary words containing "ai" are innocent', () {
      final p = pbp(() => baseProposal(instruction: 'TAP THE PAIR ONE'));
      expect(verdictOf(p), isA<VerdictValid>());
    });
  });

  group('localized challenges (non-English locales)', () {
    Map<String, Object?> italian({
      String instruction = "TOCCA L'UNICO BLU",
      Map<String, String>? failLine,
    }) {
      final m = baseProposal(
        instruction: instruction,
        failLine: failLine ?? {'it': 'IL BLU ERA IL PRIMO.'},
      );
      for (final e in (m['elements'] as List).cast<Map<String, Object?>>()) {
        e['label'] = e['label'] == 'BLUE' ? 'BLU' : 'ROSSO';
      }
      return m;
    }

    ValidationContext it() => ctx(locale: AppLocale.it);

    test('an Italian proposal with accents and Italian verbs is valid', () {
      expect(
        validator.validate(
            pbp(() => italian(instruction: 'TOCCA IL BLU, PERCHÉ SÌ')), it()),
        isA<VerdictValid>(),
      );
    });

    test('non-English instructions may run to 10 words, not 11', () {
      const ten = 'TOCCA SOLO IL BLU E NON IL ROSSO PER FAVORE';
      const eleven = 'TOCCA SOLO IL BLU E NON IL ROSSO PER FAVORE ORA';
      expect(validator.validate(pbp(() => italian(instruction: ten)), it()),
          isA<VerdictValid>());
      expect(validator.validate(pbp(() => italian(instruction: eleven)), it()),
          isA<VerdictRetryableForcedExit>());
    });

    test('accented lowercase still breaks the uppercase law', () {
      expect(
        validator.validate(pbp(() => italian(instruction: 'TOCCA IL BLù')), it()),
        isA<VerdictRetryableForcedExit>(),
      );
    });

    test('the instruction must carry an imperative in the player language', () {
      expect(
        validator.validate(pbp(() => italian(instruction: 'TAP THE BLUE')), it()),
        hasReason('instruction.verb'),
      );
    });

    test('ids and enum names stay strict ASCII even outside English', () {
      final m = italian();
      final elements = (m['elements'] as List).cast<Map<String, Object?>>();
      elements.first['id'] = 'é1';
      m['correctAnswer'] = {'elementId': 'é1', 'startsCorrect': false};
      expect(validator.validate(pbp(() => m), it()), hasReason('envelope.ascii'));
    });

    test('a localized meta-AI reference is rejected', () {
      expect(
        validator.validate(
            pbp(() => italian(instruction: 'TOCCA IL MODELLO BLU')), it()),
        hasReason('tone.metaAi'),
      );
    });

    test('English keeps its under-8-words law', () {
      const eight = 'TAP THE ONLY BLUE ONE RIGHT NOW PLEASE';
      expect(verdictOf(pbp(() => baseProposal(instruction: eight))),
          isA<VerdictRetryableForcedExit>());
    });
  });
}

// --- helpers ---------------------------------------------------------------

/// A fully-valid `dont_tap_odd` proposal: needs a real shape AND label
/// difference (its contract) plus an allowed trick.
ChallengeProposal dontTapOddProposal() => pbp(() => baseProposal(
      move: 'dont_tap_odd',
      action: 'donot_tap',
      kind: 'trick',
      senseDecoys: const ['shape', 'label'],
      instruction: "DON'T TAP THE ODD SHAPES",
      elements: [
        {
          'id': 'e1',
          'label': 'ODD',
          'color': 'blue',
          'shape': 'triangle',
          'scale': 1.0,
          'rotation': 0,
          'dx': 0,
          'dy': 0,
          'opacity': 1.0,
          'hidden': false,
        },
        {
          'id': 'e2',
          'label': 'ODD',
          'color': 'green',
          'shape': 'circle',
          'scale': 1.0,
          'rotation': 0,
          'dx': 0,
          'dy': 0,
          'opacity': 1.0,
          'hidden': false,
        },
        {
          'id': 'e3',
          'label': 'EVEN',
          'color': 'yellow',
          'shape': 'triangle',
          'scale': 1.0,
          'rotation': 0,
          'dx': 0,
          'dy': 0,
          'opacity': 1.0,
          'hidden': false,
        },
      ],
      difficulty: {'level': 8, 'timeLimitMs': 2500, 'trickType': 'fake_button'},
    ));

List<Map<String, Object?>> mutatedElement(
  int count, {
  String? id,
  String? color,
  String? shape,
  double? scale,
  double? opacity,
  double? rotation,
  double? dx,
  double? dy,
}) {
  final base = baseProposal()['elements'] as List;
  final copy = [
    for (final e in base) Map<String, Object?>.from(e as Map),
  ];
  final index = count - 1;
  while (index >= copy.length) {
    copy.add(Map<String, Object?>.from(copy.length > 1 ? copy[1] : copy[0]));
  }
  final target = copy[index];
  if (id != null) target['id'] = id;
  if (color != null) target['color'] = color;
  if (shape != null) target['shape'] = shape;
  if (scale != null) target['scale'] = scale;
  if (opacity != null) target['opacity'] = opacity;
  if (rotation != null) target['rotation'] = rotation;
  if (dx != null) target['dx'] = dx;
  if (dy != null) target['dy'] = dy;
  return copy;
}

Matcher hasReason(String reason) => isA<VerdictInvalid>()
    .having((v) => v.reason, 'reason', reason);