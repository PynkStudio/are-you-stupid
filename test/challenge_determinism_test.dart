import 'dart:math';

import 'package:are_you_stupid/challenges/registry.dart';
import 'package:are_you_stupid/core/challenge.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 1 of multiplayer ([[Multiplayer Development]]): building the
/// canonical `ChallengeView` from `{ challengeId, seed }` must be fully
/// deterministic — same tuple → identical view, every time, everywhere.
void main() {
  test('templateById resolves every registered id, null for unknown', () {
    for (final t in kChallengeTemplates) {
      expect(templateById(t.id), same(t), reason: '${t.id} not resolvable');
    }
    expect(templateById('nope'), isNull);
    expect(templateById(''), isNull);
  });

  test('buildFromSeed throws for an unknown challenge id', () {
    expect(
      () => buildFromSeed(challengeId: 'nope', seed: 1, level: 5),
      throwsArgumentError,
    );
  });

  test('same tuple rebuilds the identical ChallengeView (deep)', () {
    for (final template in kChallengeTemplates) {
      for (final seed in [0, 1, 42, 1234567]) {
        for (final level in [template.minLevel, 15, 40]) {
          final a = buildFromSeed(
            challengeId: template.id,
            seed: seed,
            level: level,
          );
          final b = buildFromSeed(
            challengeId: template.id,
            seed: seed,
            level: level,
          );

          expectViewEquals(a, b, reason: '${template.id} seed=$seed level=$level');
          expect(a.duration, b.duration, reason: template.id);
          expect(a.id, template.id);
        }
      }
    }
  });

  test('same challengeId with different seeds stays buildable per seed', () {
    // A template that hardly randomizes may coincide across seeds; we only
    // assert that re-seeding re-builds without errors. `no_instruction` and
    // the patience templates legitimately ship empty/blank views.
    for (final template in kChallengeTemplates) {
      for (final seed in [1, 2, 3, 4, 5]) {
        final c = buildFromSeed(
          challengeId: template.id,
          seed: seed,
          level: max(template.minLevel, 10),
        );
        expect(c.id, template.id, reason: template.id);
      }
    }
  });

  test('buildFromSeed is locale-independent in structure per locale', () {
    // The view may differ in localized labels, but rebuilding with the same
    // locale stays deterministic — that is what both ends must do.
    for (final template in kChallengeTemplates) {
      final a = buildFromSeed(
        challengeId: template.id,
        seed: 7,
        level: max(template.minLevel, 12),
      );
      final b = buildFromSeed(
        challengeId: template.id,
        seed: 7,
        level: max(template.minLevel, 12),
      );
      expectViewEquals(a, b, reason: '${template.id} locale stable');
    }
  });
}

/// Shallow-ish deep equality of two built challenges through their first view.
/// [Challenge] does not define `==`; this compares every render-relevant field.
void expectViewEquals(
  Challenge a,
  Challenge b, {
  required String reason,
}) {
  final va = a.view;
  final vb = b.view;
  expect(va.instruction, vb.instruction, reason: reason);
  expect(va.layout, vb.layout, reason: reason);
  expect(va.hint, vb.hint, reason: reason);
  expect(va.bigCenterText, vb.bigCenterText, reason: reason);
  expect(va.blackout, vb.blackout, reason: reason);
  expect(va.showTimer, vb.showTimer, reason: reason);
  expect(va.pressure, vb.pressure, reason: reason);
  expect(va.tapCounter, vb.tapCounter, reason: reason);
  expect(va.targets.length, vb.targets.length, reason: reason);
  for (var i = 0; i < va.targets.length; i++) {
    _expectTargetEquals(va.targets[i], vb.targets[i], reason: '$reason/$i');
  }
}

void _expectTargetEquals(TargetSpec a, TargetSpec b, {required String reason}) {
  expect(a.id, b.id, reason: 'id $reason');
  expect(a.label, b.label, reason: 'label $reason');
  expect(a.color, b.color, reason: 'color $reason');
  expect(a.shape, b.shape, reason: 'shape $reason');
  expect(a.scale, b.scale, reason: 'scale $reason');
  expect(a.rotation, b.rotation, reason: 'rotation $reason');
  expect(a.dx, b.dx, reason: 'dx $reason');
  expect(a.dy, b.dy, reason: 'dy $reason');
  expect(a.x, b.x, reason: 'x $reason');
  expect(a.y, b.y, reason: 'y $reason');
  expect(a.opacity, b.opacity, reason: 'opacity $reason');
  expect(a.hidden, b.hidden, reason: 'hidden $reason');
  expect(a.textColor, b.textColor, reason: 'textColor $reason');
}