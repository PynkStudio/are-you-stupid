/// Regenerates the golden JSONL wire fixtures for the Swift protocol mirror.
///
/// Runs the pure-Dart codec (`lib/multiplayer/protocol/protocol.dart`) over a
/// representative message for every wire type and writes one JSONL line per
/// message to `tvos/Tests/AYSProtocolTests/Fixtures/messages.golden.jsonl`.
/// Each line self-verifies by round-tripping through `PartyProtocol.decode`.
///
/// The serverless host then cross-checks itself against these bytes: Swift
/// decodes each golden line and asserts the same field values (see
/// `tvos/Tests/AYSProtocolTests/ProtocolTests.swift`).
///
/// Usage (from the repo root):
///   dart run tool/gen_protocol_fixtures.dart
library;

import 'dart:io';

import 'package:are_you_stupid/multiplayer/protocol/protocol.dart';

const String _out = 'tvos/Tests/AYSProtocolTests/Fixtures/messages.golden.jsonl';

void main() {
  const info = PlayerInfo(
    playerId: 'c1',
    playerName: 'MASSIMO',
    emoji: 'smile',
    ready: true,
  );
  const infoUnready = PlayerInfo(playerId: 'c2', playerName: 'SAMI', ready: false);

  final messages = <PartyMessage>[
    const Hello(appName: 'AreYouStupid', appVersion: '1.0', ts: 100),
    const HostHello(
      hostName: 'Living Room TV',
      roomCode: '7F4K',
      maxPlayers: 8,
      protocolFeatures: ['lss', 'battle', 'count'],
      ts: 200,
    ),
    const Rejected(reason: 'protocol version mismatch', ts: 300),
    const JoinRoom(playerName: 'MASSIMO', emoji: 'smile', ts: 400),
    const PlayerJoined(
      selfClientId: 'c1',
      roomId: '7F4K',
      players: [infoUnready],
      ts: 500,
    ),
    const LeaveRoom(ts: 600),
    const PlayerLeave(playerId: 'c2', reason: 'disconnected', ts: 700),
    const PlayerReady(playerId: 'c1', ready: true, ts: 800),
    const PlayerReadyRoster(players: [info, infoUnready], ts: 900),
    const StartGame(
      mode: GameMode.stupidBattle,
      config: {'totalRounds': 20},
      ts: 1000,
    ),
    const PlayerDisconnected(playerId: 'c3', ts: 1100),
    const PlayerReconnected(playerId: 'c3', ts: 1200),
    const GameEnd(
      mode: GameMode.lastStupidStanding,
      results: [
        GameResultEntry(playerId: 'c1', score: 3, lives: 2, standing: 1),
        GameResultEntry(playerId: 'c2', score: 1, standing: 2),
      ],
      winnerId: 'c1',
      ts: 1300,
    ),
    const GameEnd(
      mode: GameMode.stupidBattle,
      results: [GameResultEntry(playerId: 'c2', score: 250, standing: 1)],
      winnerId: null,
      ts: 1320,
    ),
    const RoundStart(
      roundId: 'r1',
      challengeId: 'ch_tap_twice',
      seed: 42,
      startAt: 5000,
      durationMs: 8000,
      config: {'level': 12},
      ts: 1400,
    ),
    const RoundCountdown(roundId: 'r1', atMs: 5000, state: 'GO', ts: 1500),
    const PlayerAction(
      playerId: 'c1',
      roundId: 'r1',
      action: PartyAction.tap(targetId: 't_1', index: 2),
      correct: true,
      note: 'nice',
      clientTimestampMs: 5100,
      ts: 1600,
    ),
    const PlayerAction(
      playerId: 'c2',
      roundId: 'r1',
      action: PartyAction.count(3),
      correct: false,
      reason: 'too slow',
      ts: 1635,
    ),
    const RoundResult(
      roundId: 'r1',
      correct: true,
      reason: 'nice',
      scoreDelta: 100,
      actionReceivedMs: 5210,
      ts: 1700,
    ),
    const RoundResult(roundId: 'r1', correct: false, scoreDelta: 0, ts: 1710),
    const RoundResults(
      roundId: 'r1',
      results: [
        PlayerRoundResult(
          playerId: 'c1',
          correct: true,
          reason: 'nice',
          scoreDelta: 100,
          reactionMs: 210,
        ),
        PlayerRoundResult(playerId: 'c2', correct: false, scoreDelta: 0),
      ],
      ts: 1900,
    ),
    const RoundEnd(roundId: 'r1', ts: 2000),
    const PlayerEliminated(roundId: 'r1', playerId: 'c4', livesLeft: 0, ts: 2100),
    const PlayerScore(
      playerId: 'c1',
      mode: GameMode.stupidBattle,
      score: 250,
      standing: 1,
      ts: 2200,
    ),
    const PlayerScore(
      playerId: 'c2',
      mode: GameMode.lastStupidStanding,
      score: 1,
      lives: 2,
      standing: 2,
      ts: 2210,
    ),
    const PartyError(code: 'ROOM_FULL', detail: '8/8 players', ts: 2300),
    const AiCapabilities(
      aiAvailable: true,
      computeRank: 1,
      batteryPercent: 87,
      ts: 2400,
    ),
    const AiCapabilities(aiAvailable: false, ts: 2410),
    const AiDirectorAssignment(directorPeerId: 'c1', ts: 2500),
    const AiDirectorAssignment(directorPeerId: null, ts: 2510),
    AiRoundProposal(
      roundId: 'r2',
      proposal: const {
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
      },
      ts: 2600,
    ),
    AiChallengeRound(
      roundId: 'r2',
      proposal: const {'id': 'ai.abc12', 'source': 'ai'},
      startAt: 6000,
      durationMs: 4500,
      ts: 2700,
    ),
    const AiCommentaryProposal(
      kind: 'wrong',
      roundId: 'r2',
      text: 'Barely made it.',
      ts: 2800,
    ),
    const AiCommentary(
      kind: 'elimination',
      roundId: 'r2',
      text: 'Gone, but not forgotten.',
      ts: 2900,
    ),
  ];

  final lines = <String>[];
  for (final m in messages) {
    final line = PartyProtocol.encode(m);
    final decoded = PartyProtocol.decode(line);
    if (decoded is! DecodedOk) {
      throw StateError('fixture ${m.type} failed Dart round-trip: $decoded');
    }
    lines.add(line);
  }

  final out = File(_out)..createSync(recursive: true);
  out.writeAsStringSync('${lines.join('\n')}\n');
  stdout.writeln(
    'wrote ${lines.length} golden lines (${out.path}) — '
    'all round-trip clean',
  );
}