import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:are_you_stupid/ai/apple_ai_service.dart';
import 'package:are_you_stupid/ai/feature_flags.dart';
import 'package:are_you_stupid/ai/providers.dart';
import 'package:are_you_stupid/ai/telemetry.dart';
import 'package:are_you_stupid/i18n/app_locale.dart';

import 'challenge_validator_test.dart' show baseProposal;

Future<AiFeatureFlags> _flags({bool challengeGenerationEnabled = true}) async {
  SharedPreferences.setMockInitialValues({});
  final flags = await AiFeatureFlags.load();
  await flags.setChallengeGenerationEnabled(challengeGenerationEnabled);
  return flags;
}

// Level 5: past the starter-level exclusion (levels 1-3, tested in its own
// group below) but still band 0 for `_keyFor` (`level ~/ 10`), so every
// other test in this file behaves exactly as if it said "level 1".
const _context = ChallengeContext(level: 5, locale: AppLocale.en);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// Builds a provider and waits out the one microtask its `AiFeatureFlags`
/// load always takes (even when [flags] is already resolved, `await`ing it
/// still yields once) — every test below wants flags ready *before* its
/// first `next()` call; the separate "cold start" group above is what
/// exercises the moment before that microtask has run.
Future<AIChallengeProvider> _provider({
  required MockAppleAIService service,
  required AiFeatureFlags flags,
}) async {
  final provider =
      AIChallengeProvider(service: service, loadFlags: () async => flags);
  await _settle();
  return provider;
}

void main() {
  group('AIChallengeProvider — cold start', () {
    test('returns null before AiFeatureFlags has finished loading', () {
      final provider = AIChallengeProvider(
        service: MockAppleAIService(),
        loadFlags: () => Completer<AiFeatureFlags>().future,
      );
      expect(provider.next(_context), isNull);
    });
  });

  group('AIChallengeProvider — flag / locale / availability gating', () {
    test('flag off never touches the bridge', () async {
      final flags = await _flags(challengeGenerationEnabled: false);
      final service = MockAppleAIService();
      final provider = await _provider(service: service, flags: flags);

      expect(provider.next(_context), isNull);
      await _settle();
      expect(service.calls.containsKey('requestChallenge'), isFalse);
    });

    test('an unsupported locale never touches the bridge', () async {
      final flags = await _flags();
      final service = MockAppleAIService();
      final provider = await _provider(service: service, flags: flags);

      expect(
        provider.next(const ChallengeContext(level: 1, locale: AppLocale.it)),
        isNull,
      );
      await _settle();
      expect(service.calls.containsKey('requestChallenge'), isFalse);
    });

    test('model unavailable is a cache miss, not a crash', () async {
      final flags = await _flags();
      final service = MockAppleAIService()
        ..availability = const AppleAiAvailability('unavailable');
      final provider = await _provider(service: service, flags: flags);

      expect(provider.next(_context), isNull);
      await _settle();
      expect(provider.next(_context), isNull);
    });

    // CLAUDE.md design pillar: "Levels 1-3 stay trivial (starter: true
    // templates only)". The scripted registry enforces this via
    // `ChallengeGenerator`'s own `starter` filter, but a `ChallengeProposal`
    // has no `starter` flag at all — so without an explicit exclusion here,
    // `FallbackChallengeProvider` would happily serve a non-trivial
    // AI-generated round on level 1. Found while writing the Phase 10
    // full-run widget test (see Decision Log).
    for (final level in [1, 2, 3]) {
      test('level $level (starter) never touches the bridge, even when everything else is ready', () async {
        final flags = await _flags();
        final service = MockAppleAIService()
          ..nextChallengeResult = AppleAiProposalResult.ok(baseProposal());
        final provider = await _provider(service: service, flags: flags);

        expect(
          provider.next(ChallengeContext(level: level, locale: AppLocale.en)),
          isNull,
        );
        await _settle();
        expect(service.calls.containsKey('requestChallenge'), isFalse);
      });
    }

    test('level 4 (first non-starter level) is eligible', () async {
      final flags = await _flags();
      final service = MockAppleAIService()
        ..nextChallengeResult = AppleAiProposalResult.ok(baseProposal());
      final provider = await _provider(service: service, flags: flags);

      provider.next(const ChallengeContext(level: 4, locale: AppLocale.en));
      await _settle();
      expect(
        provider.next(const ChallengeContext(level: 4, locale: AppLocale.en)),
        isNotNull,
      );
    });
  });

  group('AIChallengeProvider — a validated proposal reaches the cache', () {
    test('a valid proposal is popped on a later call, with ai provenance', () async {
      final flags = await _flags();
      final service = MockAppleAIService()
        ..nextChallengeResult =
            AppleAiProposalResult.ok(baseProposal());
      final provider = await _provider(service: service, flags: flags);

      expect(provider.next(_context), isNull); // first call: nothing cached yet
      await _settle();

      final second = provider.next(_context);
      expect(second, isNotNull);
      expect(second!.source, 'ai');
      expect(second.id, 'ai.abc12');
    });

    test('the request carries level, tricks, profile and vocabulary — not just locale', () async {
      final flags = await _flags();
      final service = MockAppleAIService()
        ..nextChallengeResult = AppleAiProposalResult.ok(baseProposal());
      final provider = AIChallengeProvider(
        service: service,
        loadFlags: () async => flags,
        profileSnapshot: () => PlayerGameplayProfile(fastestStreak: 7),
      );
      await _settle();

      provider.next(const ChallengeContext(level: 12, locale: AppLocale.en, allowTricks: true));
      await _settle();

      final payload = service.calls['requestChallenge']!.single['profile'] as Map;
      expect(payload['level'], 12);
      expect(payload['allowTricks'], isTrue);
      expect((payload['playerProfile'] as Map)['fastestStreak'], 7);
      expect(payload['recentChallenges'], isEmpty); // nothing served yet
      expect(payload['availableMechanics'], isNotEmpty);
    });

    test('an invalid proposal (bad envelope) never reaches the cache', () async {
      final flags = await _flags();
      final service = MockAppleAIService()
        ..nextChallengeResult = AppleAiProposalResult.ok(
          baseProposal(id: 'not-a-valid-id'),
        );
      final provider = await _provider(service: service, flags: flags);

      provider.next(_context);
      await _settle();

      expect(provider.next(_context), isNull);
    });

    test('a bridge failure never reaches the cache', () async {
      final flags = await _flags();
      final service = MockAppleAIService()
        ..nextChallengeResult =
            const AppleAiProposalResult.fail(AppleAiError('refusal'));
      final provider = await _provider(service: service, flags: flags);

      provider.next(_context);
      await _settle();

      expect(provider.next(_context), isNull);
    });

    test('a malformed proposal JSON (FormatException) never reaches the cache', () async {
      final flags = await _flags();
      final service = MockAppleAIService()
        ..nextChallengeResult = AppleAiProposalResult.ok(
          (baseProposal()..remove('mechanic')),
        );
      final provider = await _provider(service: service, flags: flags);

      provider.next(_context);
      await _settle();

      expect(provider.next(_context), isNull);
    });
  });

  group('AIChallengeProvider — cache key invalidation', () {
    test('crossing a level band invalidates the cache instead of serving a stale locale/level mix', () async {
      final flags = await _flags();
      final service = MockAppleAIService()
        ..nextChallengeResult = AppleAiProposalResult.ok(baseProposal());
      final provider = await _provider(service: service, flags: flags);

      provider.next(_context); // level 5, band 0
      await _settle();
      expect(provider.next(_context), isNotNull); // consumes the cached item

      // A different mechanic/decoy signature so the validator's freshness
      // (last-4-served) rule doesn't reject this as a near-duplicate of the
      // round just served above — that's a real, separate guard, not what
      // this test is about.
      service.nextChallengeResult = AppleAiProposalResult.ok(baseProposal(
        id: 'ai.xyz99',
        move: 'tap_missing_color',
        kind: 'perception',
        senseDecoys: const ['color'],
      ));

      // Cross into a new level band — the freshly-started fetch below should
      // still land (invalidate() doesn't block a new fetch on the old key).
      provider.next(const ChallengeContext(level: 15, locale: AppLocale.en));
      await _settle();
      expect(
        provider.next(const ChallengeContext(level: 15, locale: AppLocale.en)),
        isNotNull,
      );
    });
  });

  group('AIChallengeProvider — a discarded stale fetch must not poison dedupe', () {
    test('a fetch discarded by a key change does not count as served', () async {
      final flags = await _flags();
      final proposalA = baseProposal(id: 'ai.aaaaa');
      final proposalB = baseProposal(
        id: 'ai.bbbbb',
        move: 'tap_missing_color',
        kind: 'perception',
        senseDecoys: const ['color'],
      );
      final service = MockAppleAIService()
        ..nextChallengeResult = AppleAiProposalResult.ok(proposalA);
      final provider = await _provider(service: service, flags: flags);

      provider.next(_context); // starts a level-5 fetch for A
      await _settle();
      expect(provider.next(_context), isNotNull); // pops A; kicks a 2nd fetch (still A)

      // Before that second (still-A) fetch resolves, swap to B and cross a
      // level band: invalidate() marks the in-flight A-fetch stale, and a
      // fresh fetch for the new key starts, which will also read B (the
      // mock has no way to answer "which logical fetch is asking"). If the
      // stale fetch's validation had wrongly recorded B as served before
      // being discarded, the fresh fetch's own validation of that same B
      // would see a phantom self-collision and get rejected as a
      // near-duplicate of a round that was never actually shown to anyone.
      service.nextChallengeResult = AppleAiProposalResult.ok(proposalB);
      provider.next(const ChallengeContext(level: 15, locale: AppLocale.en));
      await _settle();
      expect(
        provider.next(const ChallengeContext(level: 15, locale: AppLocale.en)),
        isNotNull,
      );
    });
  });

  group('AIChallengeProvider — reset', () {
    test('reset clears the cache and dedupe state', () async {
      final flags = await _flags();
      final service = MockAppleAIService()
        ..nextChallengeResult = AppleAiProposalResult.ok(baseProposal());
      final provider = await _provider(service: service, flags: flags);

      provider.next(_context);
      await _settle();
      provider.reset();

      expect(provider.next(_context), isNull); // cache was cleared by reset
    });
  });
}
