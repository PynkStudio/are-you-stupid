import 'dart:math';

import 'package:are_you_stupid/challenges/registry.dart';
import 'package:are_you_stupid/core/challenge.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_host.dart';

/// Contract every template must respect, checked across many seeds and levels.
void main() {
  test('registry ships at least 30 templates with unique ids', () {
    expect(kChallengeTemplates.length, greaterThanOrEqualTo(30));
    final ids = kChallengeTemplates.map((t) => t.id).toSet();
    expect(ids.length, kChallengeTemplates.length);
  });

  test('starter templates exist and are available from level 1-3', () {
    final starters = kChallengeTemplates.where((t) => t.starter).toList();
    expect(starters, isNotEmpty);
    expect(starters.every((t) => t.minLevel <= 3), isTrue);
  });

  test('every template builds and behaves sanely on every level band', () {
    for (final template in kChallengeTemplates) {
      for (var seed = 0; seed < 12; seed++) {
        for (final level in [template.minLevel, 15, 40]) {
          final params = ChallengeParams(
            level: level,
            rng: Random(seed),
            speed: 1 + level * 0.03,
          );
          final challenge = template.build(params);
          final host = FakeHost();
          challenge.onStart(host);

          expect(challenge.id, template.id, reason: 'id mismatch');
          expect(
            challenge.duration.inMilliseconds,
            greaterThanOrEqualTo(600),
            reason: '${template.id} round is too short to react to',
          );
          expect(
            challenge.duration.inMilliseconds,
            lessThanOrEqualTo(8000),
            reason: '${template.id} round drags on',
          );

          final view = challenge.view;
          expect(view.instruction.split(' ').length, lessThanOrEqualTo(8),
              reason: '${template.id} instruction is too long');
          for (final t in view.targets) {
            expect(t.scale, greaterThan(0));
            expect(t.opacity, inInclusiveRange(0.2, 1.0));
          }
          // Ids must be unique so taps are unambiguous.
          final ids = view.targets.map((t) => t.id).toSet();
          expect(ids.length, view.targets.length, reason: template.id);
        }
      }
    }
  });

  test('every template can be resolved: some input always ends the round', () {
    for (final template in kChallengeTemplates) {
      final params = ChallengeParams(
        level: template.minLevel,
        rng: Random(7),
        speed: 1.0,
      );
      final challenge = template.build(params);
      final host = FakeHost();
      challenge.onStart(host);
      // Let it run out untouched: it must resolve one way or the other.
      advance(challenge, host, to: challenge.duration);
      expect(host.settled, isTrue,
          reason: '${template.id} never resolves on timeout');
    }
  });
}
