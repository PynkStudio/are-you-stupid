/// [[Development Plan]] Phase 10 — the one gap the per-phase suites never
/// closed: nobody had ever driven the *exact* provider composition
/// `game_screen.dart` builds (`AdaptiveChallengeProvider` ->
/// `FallbackChallengeProvider` -> `ScriptedChallengeProvider` +
/// `AIChallengeProvider`) through a real, multi-round [GameEngine] run.
/// Every other AI suite tests one layer in isolation with a fixed
/// [ChallengeContext] (`provider_test.dart`) or a single challenge instance
/// (`generated_challenge_runtime_test.dart`) — this is the first (and only)
/// place that plays an actual run end to end with a scripted-AI mix.
///
/// Deliberately **not** a `testWidgets` test driving real taps on rendered
/// pixels: the run must pass through levels 1-3 (scripted-only, starter
/// gate) before AI is even eligible, and which of the 4 starter templates
/// the RNG picks there is unpredictable — hand-authoring "find the right
/// button" logic per rendered template would be exactly the kind of
/// brittle, high-maintenance test this project avoids. Driving the real
/// [Challenge] objects [GameEngine] hands back (same technique as
/// `challenge_behaviour_test.dart` and `game_engine_test.dart`) exercises
/// identical engine/provider code paths without any rendering coupling.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:are_you_stupid/ai/apple_ai_service.dart';
import 'package:are_you_stupid/ai/feature_flags.dart';
import 'package:are_you_stupid/ai/generated_challenge_runtime.dart';
import 'package:are_you_stupid/ai/providers.dart';
import 'package:are_you_stupid/challenges/base.dart';
import 'package:are_you_stupid/challenges/counting_challenges.dart'
    show ExactTapsChallenge;
import 'package:are_you_stupid/challenges/registry.dart';
import 'package:are_you_stupid/core/challenge.dart';
import 'package:are_you_stupid/core/challenge_generator.dart';
import 'package:are_you_stupid/core/game_engine.dart';
import 'package:are_you_stupid/core/game_state.dart';

import 'challenge_validator_test.dart' show baseProposal;
import '../support/fake_host.dart' show tapOn;

Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// Ticks [engine] forward until [done] holds, so the test survives a hang
/// as a failing assertion instead of the suite's own timeout.
Future<void> _tickUntil(
  GameEngine engine,
  bool Function() done, {
  Duration step = const Duration(milliseconds: 20),
  int maxSteps = 400,
}) async {
  for (var i = 0; i < maxSteps && !done(); i++) {
    engine.tick(step);
    await _settle();
  }
  expect(done(), isTrue,
      reason: 'engine got stuck: phase=${engine.state.phase}, '
          'level=${engine.state.level}');
}

/// Answers whichever challenge is currently live correctly. Handles every
/// shape this run can ever produce: the 3 `TapTargetChallenge`-based
/// starters (`tap_color`, `tap_number`, `dont_tap_color` — all expose the
/// winning id(s) via the public `correctIds`), `tap_twice`
/// (`ExactTapsChallenge`, exactly 2 taps on `'pad'`), and an AI-generated
/// `GeneratedChallengeRuntime` (whose `tap` mechanic wins on
/// `proposal.correctAnswer.elementId`).
void _answerCorrectly(GameEngine engine) {
  final challenge = engine.state.challenge!;
  if (challenge is GeneratedChallengeRuntime) {
    engine.handleTap(tapOn(challenge.proposal.correctAnswer.elementId));
  } else if (challenge is TapTargetChallenge) {
    engine.handleTap(tapOn(challenge.correctIds.first));
  } else if (challenge is ExactTapsChallenge) {
    engine.handleTap(tapOn('pad'));
    engine.handleTap(tapOn('pad'));
  } else {
    fail('unhandled challenge type in test driver: ${challenge.runtimeType}');
  }
}

/// Plays the current round to completion (answers it, then ticks past the
/// correct flash into the next level) and returns whether it was AI-sourced.
Future<bool> _playRound(GameEngine engine) async {
  final startLevel = engine.state.level;
  final wasAi = engine.state.challenge is GeneratedChallengeRuntime;
  _answerCorrectly(engine);
  await _tickUntil(
    engine,
    () =>
        engine.state.level > startLevel ||
        engine.state.phase == GamePhase.gameOver,
  );
  return wasAi;
}

void main() {
  test(
      'a full run through the production provider composition: AI served '
      'mid-run, an invalid proposal falls back silently, a mid-session mode '
      'switch takes effect next round, no error ever surfaces', () async {
    SharedPreferences.setMockInitialValues({});
    final flags = await AiFeatureFlags.load();
    final service = MockAppleAIService()
      ..nextChallengeResult = AppleAiProposalResult.ok(baseProposal(
        id: 'ai.aaaa1',
        move: 'tap_true_color',
        senseDecoys: const ['color', 'label'],
      ));

    // The exact composition `game_screen.dart` builds, with one deliberate
    // narrowing: the scripted floor only draws from the 4 `starter: true`
    // templates (`tap_color`, `tap_number`, `tap_twice`, `dont_tap_color`)
    // instead of the full 39-template registry. `ChallengeGenerator`'s own
    // level gate only *restricts to* starters below level 4 — it doesn't
    // *exclude* them above it — so real levels 4+ would otherwise hand back
    // any of ~39 arbitrary templates, and this test's driver only needs to
    // answer whichever *scripted* challenge shows up correctly (a generic
    // "any template, any level" answer-finder is a much bigger, more
    // brittle undertaking this test doesn't need — the full registry is
    // already exhaustively covered per-template by `challenge_behaviour_test.dart`
    // and `challenge_templates_test.dart`). This narrowing only shrinks the
    // scripted-fallback pool; the real `AIChallengeProvider`, `PrefetchLoop`,
    // `ChallengeValidator` and `AdaptiveChallengeProvider` are untouched.
    final provider = AdaptiveChallengeProvider(
      inner: FallbackChallengeProvider(
        scripted: ScriptedChallengeProvider(
          generator: ChallengeGenerator(
            templates: kChallengeTemplates.where((t) => t.starter).toList(),
            random: Random(7),
          ),
        ),
        ai: AIChallengeProvider(
          service: service,
          loadFlags: () async => flags,
        ),
      ),
    );

    final events = <GameEvent>[];
    final engine = GameEngine(provider: provider, random: Random(7));
    engine.addEventListener((event, state) => events.add(event));

    engine.startRun();
    await _tickUntil(engine, () => engine.state.phase == GamePhase.playing);

    // Levels 1-3: the starter gate (CLAUDE.md's "levels 1-3 stay trivial")
    // must hold even though the mock is primed with an always-valid AI
    // proposal from the very first round.
    for (var level = 1; level <= 3; level++) {
      expect(engine.state.level, level);
      expect(engine.state.challenge, isNot(isA<GeneratedChallengeRuntime>()),
          reason: 'level $level must stay scripted-only (starter gate)');
      await _playRound(engine);
    }

    // Levels 4+: eligible now. The prefetch ring needs one "miss" round to
    // kick its first fetch before anything is actually ready to pop, so
    // sweep a few rounds — alternating the mocked proposal's mechanic each
    // time a fetch might fire, since the validator's freshness check would
    // otherwise reject the same mechanic/decoy signature served twice in a
    // row. Every proposal id below must match `_envelope`'s
    // `^ai\.[a-z0-9]{5}$` — a same-length-but-hyphenated id like
    // `ai.round-1` fails that regex and gets rejected before any other
    // check runs, silently keeping every round scripted; this is exactly
    // the failure mode this test's first draft hit (see Decision Log).
    var sawAiRound = false;
    for (var i = 0; i < 4; i++) {
      service.nextChallengeResult = AppleAiProposalResult.ok(baseProposal(
        id: 'ai.bbbb${i + 1}',
        move: i.isEven ? 'tap_true_color' : 'tap_missing_color',
        senseDecoys: i.isEven ? const ['color', 'label'] : const ['color'],
      ));
      if (await _playRound(engine)) sawAiRound = true;
    }
    expect(sawAiRound, isTrue,
        reason: 'the AI path never actually served a round in '
            '${engine.state.level - 3} eligible attempts');

    // Silent fallback: the bridge answers with something the validator must
    // reject (only 1 element — `_elementBounds` requires 2-6) — the round
    // must still resolve to a normal, playable (scripted) challenge, with
    // no crash and no player-visible sign anything went wrong.
    service.nextChallengeResult = AppleAiProposalResult.ok(baseProposal(
      id: 'ai.ccccc',
      elements: [
        {
          'id': 'only',
          'label': 'X',
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
      correct: {'elementId': 'only', 'startsCorrect': false},
    ));
    expect(engine.state.challenge, isNotNull);
    await _playRound(engine);
    expect(engine.state.challenge, isNot(isA<GeneratedChallengeRuntime>()),
        reason: 'an invalid proposal must fall back to scripted silently');

    // Mid-session mode switch: even with a perfectly valid proposal queued,
    // turning AI generation off must take effect from the very next round.
    await flags.setChallengeGenerationEnabled(false);
    service.nextChallengeResult = AppleAiProposalResult.ok(baseProposal(
      id: 'ai.ddddd',
      move: 'tap_true_color',
      senseDecoys: const ['color', 'label'],
    ));
    await _playRound(engine);
    expect(engine.state.challenge, isNot(isA<GeneratedChallengeRuntime>()),
        reason: 'aiChallengeGenerationEnabled=false must apply immediately');

    // Across the whole run — starter rounds, cold-cache misses, the invalid
    // proposal, and the mode switch — every single round was answered
    // correctly and resolved cleanly: `wrong` never fired even once, and
    // nothing threw. `GameEvent` has no "error" member at all (no in-game
    // AI error state exists to leak — see Error States and Failure
    // Communication), so this is the strongest assertion the type system
    // and the engine's own event vocabulary allow.
    expect(events, isNot(contains(GameEvent.wrong)));
    expect(events.first, GameEvent.runStarted);
    expect(events, contains(GameEvent.levelStarted));
  });
}
