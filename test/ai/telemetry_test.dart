import 'dart:convert';
import 'dart:math';

import 'package:are_you_stupid/ai/generated_challenge.dart';
import 'package:are_you_stupid/ai/providers.dart';
import 'package:are_you_stupid/ai/telemetry.dart';
import 'package:are_you_stupid/core/challenge.dart';
import 'package:are_you_stupid/core/challenge_generator.dart';
import 'package:are_you_stupid/core/difficulty.dart';
import 'package:are_you_stupid/core/game_engine.dart';
import 'package:are_you_stupid/i18n/app_locale.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mistake classifier', () {
    Duration d = const Duration(milliseconds: 2000);

    test('tag-classifiable failures map to their categories', () {
      for (final tag in [
        ChallengeTag.memory,
        ChallengeTag.counting,
        ChallengeTag.reaction,
        ChallengeTag.patience,
      ]) {
        final expected = switch (tag) {
          ChallengeTag.memory => MistakeCategory.memoryFailure,
          ChallengeTag.counting => MistakeCategory.countingFailure,
          ChallengeTag.reaction || ChallengeTag.patience =>
            MistakeCategory.timingFailure,
          _ => null,
        };
        expect(
          classifyFailure(
            tag: tag,
            elapsed: const Duration(milliseconds: 400),
            duration: d,
            timedOut: false,
          ),
          expected,
        );
      }
    });

    test('a timeout on a non-tag mechanic is a timing failure', () {
      expect(
        classifyFailure(
          tag: ChallengeTag.color,
          elapsed: d,
          duration: d,
          timedOut: true,
        ),
        MistakeCategory.timingFailure,
      );
    });

    test('a single fast wrong tap on color/word reads as impulse', () {
      expect(
        classifyFailure(
          tag: ChallengeTag.color,
          elapsed: const Duration(milliseconds: 150),
          duration: d,
          timedOut: false,
        ),
        MistakeCategory.impulsiveTap,
      );
      expect(
        classifyFailure(
          tag: ChallengeTag.word,
          elapsed: const Duration(milliseconds: 100),
          duration: d,
          timedOut: false,
        ),
        MistakeCategory.impulsiveTap,
      );
    });

    test('a slow, deliberate wrong tap is unclassifiable', () {
      expect(
        classifyFailure(
          tag: ChallengeTag.color,
          elapsed: const Duration(milliseconds: 1200),
          duration: d,
          timedOut: false,
        ),
        isNull,
      );
    });

    test('name round-trips through persist/load', () {
      expect(mistakeCategoryFromName('impulsiveTap'), MistakeCategory.impulsiveTap);
      expect(mistakeCategoryFromName('timingFailure'), MistakeCategory.timingFailure);
      expect(mistakeCategoryFromName('nope'), isNull);
    });
  });

  group('PlayerGameplayProfile', () {
    test('JSON round-trips rates, counters and int-keyed difficulty', () {
      final p = PlayerGameplayProfile(
        totalRoundsPlayed: 41,
        fastestStreak: 7,
        successRateByMechanic: {'tap_color': 0.5, 'swap': 0.25},
        mistakeRatesByCategory: {'impulsiveTap': 0.6, 'timingFailure': 0.4},
        averageReactionTimeMs: 812.5,
        reactionTimeVarianceMs: 120.0,
        winRateByDifficulty: {1: 1.0, 6: 0.2},
      );

      final json = jsonDecode(jsonEncode(p.toJson()));
      final back = PlayerGameplayProfile.fromJson(json as Map<String, dynamic>);

      expect(back.totalRoundsPlayed, 41);
      expect(back.fastestStreak, 7);
      expect(back.successRateByMechanic['tap_color'], 0.5);
      expect(back.successRateByMechanic['swap'], 0.25);
      expect(back.mistakeRatesByCategory['impulsiveTap'], 0.6);
      expect(back.averageReactionTimeMs, 812.5);
      expect(back.reactionTimeVarianceMs, 120.0);
      expect(back.winRateByDifficulty[1], 1.0);
      expect(back.winRateByDifficulty[6], 0.2);
      expect(back.mostCommonMistakeCategory, 'impulsiveTap');
      expect(back.isEmpty, isFalse);
    });

    test('empty profile is empty with no dominant category', () {
      expect(PlayerGameplayProfile().isEmpty, isTrue);
      expect(PlayerGameplayProfile().mostCommonMistakeCategory, isNull);
    });
  });

  group('TelemetryCollector', () {
    late SharedPreferences prefs;

    /// Builds a real engine with a single starter stub; correct on 'good',
    /// wrong on anything else.
    GameEngine buildEngine() => GameEngine(
          provider: FallbackChallengeProvider(
            scripted: ScriptedChallengeProvider(
              generator: ChallengeGenerator(
                templates: [
                  ChallengeTemplate(
                    id: 'stub',
                    tag: ChallengeTag.color,
                    build: _StubChallenge.new,
                    starter: true,
                  ),
                ],
                random: Random(1),
              ),
            ),
          ),
          random: Random(1),
        );

    void tick(GameEngine e, int ms) {
      for (var i = 0; i < ms ~/ 16; i++) {
        e.tick(const Duration(milliseconds: 16));
      }
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('observes a run into an adaptive profile', () {
      final engine = buildEngine();
      final collector = TelemetryCollector(prefs: prefs, engine: engine);
      collector.load();

      engine.startRun();
      tick(engine, 600); // intro beats, then level 1 playing
      engine.handleTap(
          const TapInfo(targetId: 'good', elapsed: Duration.zero));
      expect(collector.profile.totalRoundsPlayed, 1);
      expect(collector.profile.fastestStreak, 1);
      expect(collector.profile.successRateByMechanic['stub'], 1.0);
      expect(collector.profile.averageReactionTimeMs, isNotNull);
      expect(collector.profile.winRateByDifficulty[1], 1.0);

      tick(engine, 300); // correct flash, then level 2 playing
      engine.handleTap(const TapInfo(targetId: 'bad', elapsed: Duration.zero));
      expect(collector.profile.totalRoundsPlayed, 2);
      expect(collector.profile.successRateByMechanic['stub'], 0.5);
      expect(collector.profile.winRateByDifficulty[2], 0.0);
      // Level 2 taps fast (<35% of the 2s limit) → impulsive.
      expect(collector.profile.mistakeRatesByCategory['impulsiveTap'], 1.0);

      collector.detach();
    });

    test('persists and reloads through the SharedPreferences mock', () async {
      final engine = buildEngine();
      final collector = TelemetryCollector(prefs: prefs, engine: engine);
      await collector.load();

      engine.startRun();
      tick(engine, 600);
      engine.handleTap(
          const TapInfo(targetId: 'good', elapsed: Duration.zero));
      await collector.persist();

      final reloaded = TelemetryCollector(prefs: prefs);
      await reloaded.load();
      expect(reloaded.profile.totalRoundsPlayed, 1);
      expect(reloaded.profile.successRateByMechanic['stub'], 1.0);
    });

    test('reset wipes session and disk state', () async {
      final engine = buildEngine();
      final collector = TelemetryCollector(prefs: prefs, engine: engine);
      await collector.load();

      engine.startRun();
      tick(engine, 600);
      engine.handleTap(
          const TapInfo(targetId: 'good', elapsed: Duration.zero));
      await collector.persist();

      await collector.reset();
      expect(collector.profile.isEmpty, isTrue);
      expect(prefs.getString(kProfileKey), isNull);

      final reloaded = TelemetryCollector(prefs: prefs);
      await reloaded.load();
      expect(reloaded.profile.isEmpty, isTrue);
    });

    test('a corrupt persisted profile falls back to empty', () async {
      prefs.setString(kProfileKey, '{not json');
      final collector = TelemetryCollector(prefs: prefs);
      final p = await collector.load();
      expect(p.isEmpty, isTrue);
    });

    test('a run restart clears the in-run window but keeps all-time counters',
        () {
      final engine = buildEngine();
      final collector = TelemetryCollector(prefs: prefs, engine: engine);
      collector.load();

      engine.startRun();
      tick(engine, 600);
      engine.handleTap(
          const TapInfo(targetId: 'good', elapsed: Duration.zero));
      engine.startRun();
      expect(collector.profile.totalRoundsPlayed, 1);
      expect(collector.profile.successRateByMechanic['stub'], isNull);
    });

    test('detach stops observing without throwing', () {
      final engine = buildEngine();
      final collector = TelemetryCollector(prefs: prefs, engine: engine);
      engine.startRun();
      collector.detach();
      engine.startRun();
      expect(collector.profile.totalRoundsPlayed, 0);
    });
  });

  group('AdaptiveChallengeProvider', () {
    ChallengeContext ctx =
        const ChallengeContext(level: 6, locale: AppLocale.en);

    test('cold start passes through the inner provider untouched', () {
      final inner = _SequenceProvider(['a', 'b', 'c']);
      final adaptive = AdaptiveChallengeProvider(inner: inner);
      expect(adaptive.next(ctx)!.challenge.id, 'a');
      expect(adaptive.next(ctx)!.challenge.id, 'b');
      expect(adaptive.next(ctx)!.challenge.id, 'c');
    });

    test('territory prefers the mechanic the player is weakest at', () {
      final profile = PlayerGameplayProfile(
        successRateByMechanic: {'a': 0.1, 'b': 0.9, 'c': 0.9},
      );
      // Inner keeps offering 'b' first; province is only won by re-rolling
      // until a struggling-mechanic candidate shows up.
      final inner = _SequenceProvider(['b', 'a', 'c']);
      final adaptive =
          AdaptiveChallengeProvider(inner: inner, profile: profile);
      expect(adaptive.next(ctx)!.challenge.id, 'a');
      expect(adaptive.next(ctx)!.challenge.id, 'a');
    });

    test('never over-serves one mechanic within a window (variety guard)',
        () {
      // Inner serves 'a' 2/3 of the time — explosive without the guard.
      // Needs at least 3 distinct ids for the invariant below to even be
      // satisfiable: with only 2 ids and cap 3, an 8-window can hold at
      // most 3+3=6 < 8 — no reroll budget on earth fixes a test that asks
      // for something mathematically impossible. This bug (not a production
      // one) was caught by actually working the pigeonhole argument rather
      // than assuming a failing test always means the code is wrong.
      final inner = _SequenceProvider(List.generate(
          60, (i) => i % 3 == 2 ? (i % 6 == 2 ? 'b' : 'c') : 'a'));
      final adaptive = AdaptiveChallengeProvider(inner: inner, maxRerolls: 4);

      final served = List.generate(
          30, (_) => adaptive.next(ctx)!.challenge.id);
      for (var w = 0; w + 8 <= served.length; w++) {
        final window = served.sublist(w, w + 8);
        for (final id in window.toSet()) {
          expect(
            window.where((e) => e == id).length,
            lessThanOrEqualTo(3),
            reason: 'window $w has too many $id: $window',
          );
        }
      }
    });

    test('exhausted re-rolls degrade to whatever the inner offered', () {
      final profile = PlayerGameplayProfile(
        successRateByMechanic: {'a': 0.1, 'b': 0.9},
      );
      // Inner NEVER offers the target mechanic 'a'.
      final inner = _SequenceProvider(['b', 'b', 'b']);
      final adaptive =
          AdaptiveChallengeProvider(inner: inner, profile: profile);
      expect(adaptive.next(ctx)!.challenge.id, 'b');
    });

    test('reset clears the served window', () {
      final inner = _SequenceProvider(['a', 'b']);
      final adaptive = AdaptiveChallengeProvider(inner: inner);
      adaptive.next(ctx);
      adaptive.reset();
      // After reset the window is empty again: cold start → 'a' first.
      expect(adaptive.next(ctx)!.challenge.id, 'a');
    });
  });
}

class _StubChallenge extends Challenge {
  _StubChallenge(super.params);

  @override
  String get id => 'stub';

  @override
  ChallengeTag get tag => ChallengeTag.color;

  @override
  Duration get duration => const Duration(seconds: 2);

  @override
  ChallengeView get view => const ChallengeView(
        instruction: 'TAP GOOD',
        layout: ChallengeLayout.row,
        targets: [
          TargetSpec(id: 'good'),
          TargetSpec(id: 'bad'),
        ],
      );

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.targetId == 'good') {
      host.pass();
    } else {
      host.fail(reason: 'NOPE.');
    }
  }
}

class _FakeChallenge extends Challenge {
  _FakeChallenge(this._id, this._tag)
      : super(ChallengeParams(
          level: 1,
          rng: Random(1),
          speed: Difficulty.speedForLevel(1),
          locale: AppLocale.en,
        ));

  final String _id;
  final ChallengeTag _tag;

  @override
  String get id => _id;

  @override
  ChallengeTag get tag => _tag;

  @override
  Duration get duration => const Duration(seconds: 2);

  @override
  ChallengeView get view => const ChallengeView(
        instruction: 'TAP',
        layout: ChallengeLayout.row,
        targets: [TargetSpec(id: 'x')],
      );

  @override
  void onTap(TapInfo tap, ChallengeHost host) => host.pass();
}

class _SequenceProvider implements ChallengeProvider {
  _SequenceProvider(List<String> ids) : _ids = ids;

  final List<String> _ids;
  int _i = 0;

  @override
  GeneratedChallenge? next(ChallengeContext context) {
    final id = _ids[_i % _ids.length];
    _i++;
    return GeneratedChallenge(
      challenge: _FakeChallenge(id, ChallengeTag.color),
      source: 'test',
    );
  }

  @override
  void reset() => _i = 0;
}