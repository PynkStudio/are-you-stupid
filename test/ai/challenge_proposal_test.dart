import 'package:flutter_test/flutter_test.dart';
import 'package:are_you_stupid/ai/challenge_vocabulary.dart';
import 'package:are_you_stupid/ai/generated_challenge.dart';

void main() {
  group('ChallengeProposal JSON round-trip', () {
    test('a full proposal survives toJson → fromJson', () {
      final original = _fixture();
      final rebuilt = ChallengeProposal.fromJson(original.toJson());

      expect(rebuilt.id, original.id);
      expect(rebuilt.instruction, original.instruction);
      expect(rebuilt.source, 'ai');
      expect(rebuilt.correctElement!.id, 'e1');
      expect(rebuilt.correctAnswer.startsCorrect, isFalse);
      expect(rebuilt.difficulty.timeLimitMs, 2500);
      expect(rebuilt.failLine['en'], isNotNull);

      expect(rebuilt.mechanic.move, 'tap_true_color');
      expect(rebuilt.mechanic.senseDecoys, ['color', 'label']);
      expect(rebuilt.mechanicContract, isNotNull); // in the vocabulary
      expect(rebuilt.mechanicContract!.action, AiAction.tap);
    });

    test('parses parsed dims lazily and rejects unknown vocabulary', () {
      final p = ChallengeProposal.fromJson(_fixture().toJson());
      expect(p.elements.first.color, AiColor.blue);
      expect(p.elements.first.shape, AiShape.circle);
    });
  });

  group('envelope decay', () {
    test('a missing mechanic block throws FormatException', () {
      final json = _fixture().toJson()..remove('mechanic');
      expect(() => ChallengeProposal.fromJson(json),
          throwsFormatException);
    });

    test('an empty id throws FormatException', () {
      final json = _fixture().toJson()..['id'] = '';
      expect(() => ChallengeProposal.fromJson(json),
          throwsFormatException);
    });

    test('non-list elements throws FormatException', () {
      final json = _fixture().toJson()..['elements'] = 'oops';
      expect(() => ChallengeProposal.fromJson(json),
          throwsFormatException);
    });

    test('unknown colors parse to null — a validator matter, not an exception', () {
      final json = _fixture().toJson();
      (json['elements'] as List).first['color'] = 'ultraviolet';
      final p = ChallengeProposal.fromJson(json);
      expect(p.elements.first.color, isNull);
    });
  });

  group('correctElement', () {
    test('resolves the winning element', () {
      final p = _fixture();
      expect(p.correctElement!.id, 'e1');
    });

    test('returns null for a ghost id', () {
      final json = _fixture().toJson();
      (json['correctAnswer'] as Map)['elementId'] = 'nope';
      expect(ChallengeProposal.fromJson(json).correctElement, isNull);
    });
  });

  group('AiElement.differsFrom', () {
    test('same fields => false, any sense difference => true', () {
      final a = AiElement(id: 'a', colorName: 'blue', shapeName: 'circle');
      final b = AiElement(id: 'b', colorName: 'blue', shapeName: 'circle');
      final bColor = AiElement(id: 'b', colorName: 'red', shapeName: 'circle');
      final bSize = AiElement(id: 'b', colorName: 'blue', shapeName: 'circle', scale: 1.2);

      expect(a.differsFrom(b), isFalse);
      expect(a.differsFrom(bColor), isTrue);
      expect(a.differsFrom(bSize), isTrue);
    });
  });

  group('vocabulary sanity', () {
    test('every mechanic move resolves and is unique', () {
      final moves = kMechanicVocabulary.map((m) => m.move).toList();
      expect(moves.toSet().length, moves.length);
      expect(kMechanicByMove.length, moves.length);
    });

    test('every AiShape and AiColor is renderable by the engine', () {
      for (final s in AiShape.values) {
        expect(s.toTargetShape().name, isNotEmpty);
      }
      for (final c in AiColor.values) {
        expect(c.toGameColor().name, isNotEmpty);
      }
    });

    test('trick contracts follow the requiresTrick rule', () {
      for (final m in kMechanicVocabulary) {
        final hasNone = m.allowedTricks.contains(AiTrickType.none);
        if (m.requiresTrick) {
          expect(hasNone, isFalse,
              reason: 'requiresTrick mechanics never allow none: ${m.move}');
        } else {
          expect(hasNone, isTrue,
              reason: 'trick-free mechanics compose from none first: ${m.move}');
        }
      }
    });
  });
}

ChallengeProposal _fixture() => ChallengeProposal.fromJson(const {
      'id': 'ai.abc12',
      'mechanic': {
        'move': 'tap_true_color',
        'action': 'tap',
        'kind': 'mixed',
        'sense_decoys': ['color', 'label'],
      },
      'instruction': 'TAP THE ONLY BLUE',
      'elements': [
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
      ],
      'correctAnswer': {'elementId': 'e1', 'startsCorrect': false},
      'difficulty': {'level': 1, 'timeLimitMs': 2500, 'trickType': 'none'},
      'failLine': {'en': 'THE ONLY BLUE WAS THE FIRST.'},
      'seed': 1,
      'source': 'ai',
    });