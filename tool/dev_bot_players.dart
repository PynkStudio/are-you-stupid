/// Dev-only bot players for a party room: joins N fake phones to a running
/// host (tvOS/macOS simulator or the dev host) so the lobby, rounds and the
/// live scoreboard can be exercised — and screenshotted — without N real
/// devices. Bots answer each round after a random delay, right ~70 % of
/// the time; judging is client-side ([[Multiplayer Architecture]]), so a
/// bot simply reports a verdict.
///
/// Usage:
///   `dart run tool/dev_bot_players.dart HOST PORT [COUNT]`
///
/// Not shipped: lives in tool/, never imported by lib/.
// ignore_for_file: avoid_print — a CLI dev tool talks to its user via stdout.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:are_you_stupid/multiplayer/engine/party_session.dart';
import 'package:are_you_stupid/multiplayer/engine/party_state.dart';
import 'package:are_you_stupid/multiplayer/networking/session_socket.dart';
import 'package:are_you_stupid/multiplayer/protocol/protocol.dart';

const _names = ['LUCA', 'GIULIA', 'MARCO', 'SOFIA', 'ANDREA', 'CHIARA', 'PAOLO'];
const _emojis = ['🤡', '🦄', '🐸', '🍕', '🔥', '👽', '🐙'];

Future<void> main(List<String> args) async {
  final host = args.isNotEmpty ? args[0] : '127.0.0.1';
  final port = args.length > 1 ? int.parse(args[1]) : 7777;
  final count = args.length > 2 ? int.parse(args[2]) : 3;
  final rng = Random();
  for (var i = 0; i < count; i++) {
    final transport = await SocketPartyTransport.connect(host, port);
    final session = PartySession(
      transport: transport,
      appName: 'ays-dev-bot',
      appVersion: '1.0.0',
    );
    final name = _names[i % _names.length];
    session.events.listen((event) {
      switch (event) {
        case PartyHandshakeEvent():
          session.joinRoom(playerName: name, emoji: _emojis[i % _emojis.length]);
        case PartyJoinedEvent():
          session.setReady(true);
          print('$name joined and is ready');
        case PartyCountdownEvent(:final countdown) when countdown.state == 'GO':
          Timer(Duration(milliseconds: 600 + rng.nextInt(1800)), () {
            session.sendAction(
              const PartyAction.tap(targetId: 'bot'),
              correct: rng.nextDouble() < 0.7,
              reason: 'TOO SLOW.',
            );
          });
        case PartyGameEndEvent():
          print('$name: game over');
        default:
          break;
      }
    });
    session.connect();
  }
  print('$count bots connected to $host:$port — Ctrl-C to stop');
  await ProcessSignal.sigint.watch().first;
  exit(0);
}
