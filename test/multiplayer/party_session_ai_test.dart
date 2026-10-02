import 'package:flutter_test/flutter_test.dart';
import 'package:are_you_stupid/multiplayer/engine/party_session.dart';
import 'package:are_you_stupid/multiplayer/engine/party_state.dart';
import 'package:are_you_stupid/multiplayer/networking/party_transport.dart';
import 'package:are_you_stupid/multiplayer/protocol/protocol.dart';

void main() {
  group('PartySession — AI Director messages', () {
    late InMemoryPartyTransport client;
    late InMemoryPartyTransport hostSide;
    late PartySession session;

    setUp(() {
      final pair = InMemoryPartyTransport.pair();
      client = pair.$1;
      hostSide = pair.$2;
      session = PartySession(transport: client, appName: 'test', appVersion: '1.0');
    });

    tearDown(() => session.dispose());

    test('AI_DIRECTOR_ASSIGNMENT updates state and emits an event', () async {
      final events = <PartyEvent>[];
      session.events.listen(events.add);

      hostSide.send(PartyProtocol.encode(
        const AiDirectorAssignment(directorPeerId: 'p1'),
      ));
      await Future<void>.delayed(Duration.zero);

      expect(session.state.aiDirectorPeerId, 'p1');
      expect(events.whereType<PartyDirectorAssignedEvent>(), hasLength(1));
    });

    test('a null directorPeerId clears the assignment', () async {
      hostSide.send(PartyProtocol.encode(
        const AiDirectorAssignment(directorPeerId: 'p1'),
      ));
      await Future<void>.delayed(Duration.zero);
      expect(session.state.aiDirectorPeerId, 'p1');

      hostSide.send(PartyProtocol.encode(
        const AiDirectorAssignment(directorPeerId: null),
      ));
      await Future<void>.delayed(Duration.zero);
      expect(session.state.aiDirectorPeerId, isNull);
    });

    test('AI_COMMENTARY updates state and emits an event', () async {
      final events = <PartyEvent>[];
      session.events.listen(events.add);

      hostSide.send(PartyProtocol.encode(const AiCommentary(
        kind: 'elimination',
        roundId: 'r1',
        text: 'Gone, but not forgotten.',
      )));
      await Future<void>.delayed(Duration.zero);

      expect(session.state.lastAiCommentary?.text, 'Gone, but not forgotten.');
      expect(events.whereType<PartyAiCommentaryEvent>(), hasLength(1));
    });

    test('a valid AI_CHALLENGE_ROUND opens a real, playable round', () async {
      final events = <PartyEvent>[];
      session.events.listen(events.add);

      hostSide.send(PartyProtocol.encode(AiChallengeRound(
        roundId: 'r1',
        proposal: const {
          'id': 'ai.abc12',
          'mechanic': {
            'move': 'tap_true_color',
            'action': 'tap',
            'kind': 'mixed',
            'sense_decoys': ['color'],
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
        },
        startAt: 5000,
        durationMs: 4000,
      )));
      await Future<void>.delayed(Duration.zero);

      final received = events.whereType<PartyAiChallengeRoundEvent>().single;
      expect(received.round.roundId, 'r1');
      expect(session.state.round?.id, 'r1');
      expect(session.state.round?.challenge.id, 'ai.abc12');
      expect(session.state.phase, PartyPhase.round);
    });

    test('a malformed AI_CHALLENGE_ROUND surfaces an error and opens nothing', () async {
      final events = <PartyEvent>[];
      session.events.listen(events.add);

      hostSide.send(PartyProtocol.encode(AiChallengeRound(
        roundId: 'r1',
        proposal: const {'id': 'ai.abc12'}, // missing everything else
        startAt: 5000,
        durationMs: 4000,
      )));
      await Future<void>.delayed(Duration.zero);

      expect(session.state.round, isNull);
      expect(session.state.lastError?.code, 'BAD_AI_PROPOSAL');
      expect(events.whereType<PartyErrorEvent>(), hasLength(1));
      expect(events.whereType<PartyAiChallengeRoundEvent>(), hasLength(1));
    });

    test('sendAiCapabilities/sendAiRoundProposal/sendAiCommentaryProposal reach the host', () async {
      final lines = <String>[];
      hostSide.inbound.listen(lines.add);

      session.sendAiCapabilities(aiAvailable: true, computeRank: 1, batteryPercent: 80);
      session.sendAiRoundProposal(roundId: 'r1', proposal: const {'id': 'ai.abc12'});
      session.sendAiCommentaryProposal(kind: 'wrong', roundId: 'r1', text: 'Nope.');
      await Future<void>.delayed(Duration.zero);

      expect(lines, hasLength(3));
      final capabilities = PartyProtocol.decode(lines[0]) as DecodedOk;
      expect((capabilities.message as AiCapabilities).aiAvailable, isTrue);
      final proposal = PartyProtocol.decode(lines[1]) as DecodedOk;
      expect((proposal.message as AiRoundProposal).roundId, 'r1');
      final commentary = PartyProtocol.decode(lines[2]) as DecodedOk;
      expect((commentary.message as AiCommentaryProposal).text, 'Nope.');
    });
  });
}
