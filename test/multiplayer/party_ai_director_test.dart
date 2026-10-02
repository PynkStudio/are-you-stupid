import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:are_you_stupid/ai/apple_ai_service.dart';
import 'package:are_you_stupid/ai/feature_flags.dart';
import 'package:are_you_stupid/multiplayer/ai/party_ai_director.dart';
import 'package:are_you_stupid/multiplayer/engine/party_session.dart';
import 'package:are_you_stupid/multiplayer/networking/party_transport.dart';
import 'package:are_you_stupid/multiplayer/protocol/protocol.dart';

import '../ai/challenge_validator_test.dart' show baseProposal;

Future<void> _settle() => Future<void>.delayed(Duration.zero);

Future<AiFeatureFlags> _flags({bool enabled = true, bool multiplayerDirectorEnabled = true}) async {
  SharedPreferences.setMockInitialValues({});
  final flags = await AiFeatureFlags.load();
  await flags.setChallengeGenerationEnabled(enabled);
  await flags.setCommentaryEnabled(enabled);
  await flags.setMultiplayerDirectorEnabled(multiplayerDirectorEnabled);
  return flags;
}

class _Harness {
  _Harness(this.client, this.hostSide, this.session, this.service, this.director);

  final InMemoryPartyTransport client;
  final InMemoryPartyTransport hostSide;
  final PartySession session;
  final MockAppleAIService service;
  final PartyAiDirector director;

  final List<PartyMessage> sentToHost = [];

  static Future<_Harness> create({
    bool aiAvailable = true,
    bool flagsEnabled = true,
    bool multiplayerDirectorEnabled = true,
  }) async {
    final pair = InMemoryPartyTransport.pair();
    final client = pair.$1;
    final hostSide = pair.$2;
    final session = PartySession(transport: client, appName: 'test', appVersion: '1.0');
    final service = MockAppleAIService()
      ..availability = AppleAiAvailability(aiAvailable ? 'available' : 'unavailable');
    final flags = await _flags(
      enabled: flagsEnabled,
      multiplayerDirectorEnabled: multiplayerDirectorEnabled,
    );
    final director = PartyAiDirector(
      session: session,
      service: service,
      loadFlags: () async => flags,
    );
    final harness = _Harness(client, hostSide, session, service, director);
    hostSide.inbound.listen((line) {
      final decoded = PartyProtocol.decode(line);
      if (decoded is DecodedOk) harness.sentToHost.add(decoded.message);
    });
    await _settle();
    return harness;
  }

  /// Delivers a synthetic host→client message.
  Future<void> receive(PartyMessage message) async {
    hostSide.send(PartyProtocol.encode(message));
    await _settle();
  }

  void dispose() {
    director.dispose();
    session.dispose();
  }
}

void main() {
  group('PartyAiDirector — capability announcement', () {
    test('announces availability once, right after joining', () async {
      final h = await _Harness.create(aiAvailable: true);
      await h.receive(const PlayerJoined(selfClientId: 'p1', roomId: 'R', players: []));

      final announced = h.sentToHost.whereType<AiCapabilities>().single;
      expect(announced.aiAvailable, isTrue);
      expect(announced.computeRank, 1);

      h.dispose();
    });

    test('announces unavailable when the model is not available on this device', () async {
      final h = await _Harness.create(aiAvailable: false);
      await h.receive(const PlayerJoined(selfClientId: 'p1', roomId: 'R', players: []));

      final announced = h.sentToHost.whereType<AiCapabilities>().single;
      expect(announced.aiAvailable, isFalse);
      expect(announced.computeRank, 0);

      h.dispose();
    });
  });

  group('PartyAiDirector — aiMultiplayerDirectorEnabled gate', () {
    test('announces unavailable regardless of real device availability when the flag is off', () async {
      final h = await _Harness.create(aiAvailable: true, multiplayerDirectorEnabled: false);
      await h.receive(const PlayerJoined(selfClientId: 'p1', roomId: 'R', players: []));

      final announced = h.sentToHost.whereType<AiCapabilities>().single;
      expect(announced.aiAvailable, isFalse);
      h.dispose();
    });

    test('never generates a round even if somehow named Director while the flag is off', () async {
      final h = await _Harness.create(multiplayerDirectorEnabled: false);
      h.service.nextChallengeResult = AppleAiProposalResult.ok(baseProposal());
      await h.receive(const PlayerJoined(selfClientId: 'p1', roomId: 'R', players: []));
      await h.receive(const AiDirectorAssignment(directorPeerId: 'p1'));
      await h.receive(RoundStart(
        roundId: 'r1',
        challengeId: 'tap_color',
        seed: 1,
        startAt: 0,
        durationMs: 2000,
        config: const {'level': 5},
      ));

      expect(h.sentToHost.whereType<AiRoundProposal>(), isEmpty);
      h.dispose();
    });
  });

  group('PartyAiDirector — round generation', () {
    test('does nothing when this phone is not the elected Director', () async {
      final h = await _Harness.create();
      h.service.nextChallengeResult = AppleAiProposalResult.ok(baseProposal());
      await h.receive(const PlayerJoined(selfClientId: 'p1', roomId: 'R', players: []));
      await h.receive(const AiDirectorAssignment(directorPeerId: 'someone-else'));
      await h.receive(RoundStart(
        roundId: 'r1',
        challengeId: 'tap_color',
        seed: 1,
        startAt: 0,
        durationMs: 2000,
        config: const {'level': 5},
      ));

      expect(h.sentToHost.whereType<AiRoundProposal>(), isEmpty);
      h.dispose();
    });

    test('generates and sends a validated round once elected Director', () async {
      final h = await _Harness.create();
      h.service.nextChallengeResult = AppleAiProposalResult.ok(baseProposal());
      await h.receive(const PlayerJoined(selfClientId: 'p1', roomId: 'R', players: []));
      await h.receive(const AiDirectorAssignment(directorPeerId: 'p1'));
      await h.receive(RoundStart(
        roundId: 'r1',
        challengeId: 'tap_color',
        seed: 1,
        startAt: 0,
        durationMs: 2000,
        config: const {'level': 5},
      ));

      final proposal = h.sentToHost.whereType<AiRoundProposal>().single;
      expect(proposal.proposal['id'], 'ai.abc12');

      h.dispose();
    });

    test('flag off never touches the bridge for generation', () async {
      final h = await _Harness.create(flagsEnabled: false);
      h.service.nextChallengeResult = AppleAiProposalResult.ok(baseProposal());
      await h.receive(const PlayerJoined(selfClientId: 'p1', roomId: 'R', players: []));
      await h.receive(const AiDirectorAssignment(directorPeerId: 'p1'));
      await h.receive(RoundStart(
        roundId: 'r1',
        challengeId: 'tap_color',
        seed: 1,
        startAt: 0,
        durationMs: 2000,
        config: const {'level': 5},
      ));

      expect(h.service.calls.containsKey('requestChallenge'), isFalse);
      expect(h.sentToHost.whereType<AiRoundProposal>(), isEmpty);
      h.dispose();
    });

    test('an invalid proposal from the model is never sent', () async {
      final h = await _Harness.create();
      h.service.nextChallengeResult = AppleAiProposalResult.ok(
        baseProposal(id: 'not-a-valid-id'),
      );
      await h.receive(const PlayerJoined(selfClientId: 'p1', roomId: 'R', players: []));
      await h.receive(const AiDirectorAssignment(directorPeerId: 'p1'));
      await h.receive(RoundStart(
        roundId: 'r1',
        challengeId: 'tap_color',
        seed: 1,
        startAt: 0,
        durationMs: 2000,
        config: const {'level': 5},
      ));

      expect(h.sentToHost.whereType<AiRoundProposal>(), isEmpty);
      h.dispose();
    });
  });

  group('PartyAiDirector — commentary', () {
    test('an elimination sends a validated AI commentary proposal', () async {
      final h = await _Harness.create();
      h.service.nextCommentaryResult = const AppleAiTextResult.ok('Gone, but not forgotten.');
      await h.receive(const PlayerJoined(selfClientId: 'p1', roomId: 'R', players: []));
      await h.receive(const AiDirectorAssignment(directorPeerId: 'p1'));

      await h.receive(const PlayerEliminated(roundId: 'r1', playerId: 'p2', livesLeft: 0));

      final proposal = h.sentToHost.whereType<AiCommentaryProposal>().single;
      expect(proposal.kind, 'elimination');
      expect(proposal.text, 'Gone, but not forgotten.');
      h.dispose();
    });

    test('a static-fallback line (model unavailable) is never sent to the host', () async {
      final h = await _Harness.create(aiAvailable: false);
      await h.receive(const PlayerJoined(selfClientId: 'p1', roomId: 'R', players: []));
      await h.receive(const AiDirectorAssignment(directorPeerId: 'p1'));

      await h.receive(const PlayerEliminated(roundId: 'r1', playerId: 'p2', livesLeft: 0));

      expect(h.sentToHost.whereType<AiCommentaryProposal>(), isEmpty);
      h.dispose();
    });

    test('winning the match sends winner-kind commentary', () async {
      final h = await _Harness.create();
      h.service.nextCommentaryResult = const AppleAiTextResult.ok('Never in doubt.');
      await h.receive(const PlayerJoined(selfClientId: 'p1', roomId: 'R', players: []));
      await h.receive(const AiDirectorAssignment(directorPeerId: 'p1'));

      await h.receive(const GameEnd(
        mode: GameMode.stupidBattle,
        results: [GameResultEntry(playerId: 'p1', score: 300, standing: 1)],
        winnerId: 'p1',
      ));

      final proposal = h.sentToHost.whereType<AiCommentaryProposal>().single;
      expect(proposal.kind, 'winner');
      h.dispose();
    });

    test('a non-Director phone never sends commentary, even on the same elimination event', () async {
      // Regression: an earlier draft of `_maybeSendCommentary` had no
      // `_isDirector` gate at all — every connected phone would try to
      // generate and send commentary on the same event, wastefully calling
      // the model on phones the host would just ignore anyway (only the
      // elected Director's proposal is accepted — see `RoomHost.onAiCommentaryProposal`).
      final h = await _Harness.create();
      h.service.nextCommentaryResult = const AppleAiTextResult.ok('Gone, but not forgotten.');
      await h.receive(const PlayerJoined(selfClientId: 'p1', roomId: 'R', players: []));
      // No AiDirectorAssignment naming 'p1' — this phone was never elected.

      await h.receive(const PlayerEliminated(roundId: 'r1', playerId: 'p2', livesLeft: 0));

      expect(h.sentToHost.whereType<AiCommentaryProposal>(), isEmpty);
      h.dispose();
    });

    test('losing the match sends loser-kind commentary', () async {
      final h = await _Harness.create();
      h.service.nextCommentaryResult = const AppleAiTextResult.ok('So close.');
      await h.receive(const PlayerJoined(selfClientId: 'p1', roomId: 'R', players: []));
      await h.receive(const AiDirectorAssignment(directorPeerId: 'p1'));

      await h.receive(const GameEnd(
        mode: GameMode.stupidBattle,
        results: [GameResultEntry(playerId: 'p2', score: 300, standing: 1)],
        winnerId: 'p2',
      ));

      final proposal = h.sentToHost.whereType<AiCommentaryProposal>().single;
      expect(proposal.kind, 'loser');
      h.dispose();
    });
  });
}
