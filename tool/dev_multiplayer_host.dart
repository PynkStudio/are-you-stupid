/// Throwaway dev host for manually exercising the Phase 3 multiplayer client
/// (screens, real socket transport, session/state wiring) against a real TCP
/// connection — see [[Multiplayer Development]] and [[Decision Log]].
///
/// This is NOT the Phase 4 host. It does not advertise over Bonjour/mDNS (a
/// correct responder is real host work, not a throwaway CLI's job) and it
/// reuses `test/support/party_host_reference.dart` — the same in-process
/// authority the Phase 2 test suites already prove correct — real-time
/// driven instead of clock-stepped by a test.
///
/// Usage:
///   dart run tool/dev_multiplayer_host.dart [port]
///
/// Then in the app's ENTER ROOM CODE screen, tap "DEV: HOST ADDRESS" (debug
/// builds only) and enter `<printed LAN IP>:<port>`. Room code is fixed
/// below so you don't have to read it off a QR that doesn't exist yet.
// ignore_for_file: avoid_print — a CLI dev tool talks to its user via stdout.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:are_you_stupid/multiplayer/networking/party_transport.dart';
import 'package:are_you_stupid/multiplayer/networking/session_socket.dart';
import 'package:are_you_stupid/multiplayer/protocol/protocol.dart';

import '../test/support/party_host_reference.dart';

const _roomCode = 'DEV1';
const _level = 5;
const _roundsPerGame = 6;
// Generous fixed wait per round — this is a smoke test of the client
// pipeline, not a timing benchmark, so it doesn't need to match the picked
// challenge's exact duration.
const _roundWindow = Duration(seconds: 6);

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args.first) : 7777;

  final clock = FakePartyClock(DateTime.now().millisecondsSinceEpoch);
  Timer.periodic(const Duration(milliseconds: 100), (_) => clock.advance(100));

  final host = PartyHostReference(
    hostName: 'DEV HOST',
    roomCode: _roomCode,
    // Matches the manual _runMatch loop below, so completeRound()'s own
    // `_roundIndex >= battleRounds` check fires GAME_END right on schedule.
    battleRounds: _roundsPerGame,
    clock: clock,
  );

  final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
  print('AYS dev multiplayer host');
  print('room code: $_roomCode (fixed — this is a dev tool, not real Bonjour)');
  print('port: $port');
  for (final candidate in await _lanAddresses()) {
    print('  connect via: $candidate:$port');
  }
  print('Waiting for players... type "start" + Enter once >= 2 are ready.');

  server.listen((socket) {
    print('client connected: ${socket.remoteAddress.address}:${socket.remotePort}');
    host.attachClient(SocketPartyTransport(socket));
  });

  await for (final line in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final cmd = line.trim().toLowerCase();
    if (cmd == 'start') {
      unawaited(_runMatch(host));
    } else if (cmd == 'quit' || cmd == 'exit') {
      await host.close();
      await server.close();
      exit(0);
    } else {
      print('commands: start | quit');
    }
  }
}

Future<void> _runMatch(PartyHostReference host) async {
  try {
    host.startGame(mode: GameMode.stupidBattle);
  } on StateError catch (e) {
    print('cannot start: $e');
    return;
  }
  print('match started (${host.seatCount} seats)');
  for (var round = 0; round < _roundsPerGame; round++) {
    host.startRandomRound(level: _level);
    print('round ${round + 1}/$_roundsPerGame open — waiting ${_roundWindow.inSeconds}s');
    await Future<void>.delayed(_roundWindow);
    host.completeRound();
    print('round ${round + 1} closed');
  }
  print('match finished');
}

Future<List<String>> _lanAddresses() async {
  final interfaces = await NetworkInterface.list(
    includeLoopback: false,
    type: InternetAddressType.IPv4,
  );
  return [
    for (final i in interfaces)
      for (final a in i.addresses) a.address,
  ];
}
