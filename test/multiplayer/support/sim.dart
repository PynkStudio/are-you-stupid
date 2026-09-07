/// Shared simulation harness for the multiplayer suites.
///
/// Wires one [PartyHostReference] to any number of [PartySession]s over
/// in-memory transports, all under one deterministic [FakePartyClock]
/// ([[Multiplayer Development]]). Streams are synchronous (broadcast with
/// `sync: true`), so snapshots fill the moment a message is handled — tests
/// never sleep.
library;

import 'package:are_you_stupid/challenges/registry.dart';
import 'package:are_you_stupid/multiplayer/engine/party_session.dart';
import 'package:are_you_stupid/multiplayer/engine/party_state.dart';
import 'package:are_you_stupid/multiplayer/networking/party_transport.dart';
import 'package:are_you_stupid/multiplayer/protocol/protocol.dart';

import '../../support/fake_host.dart' as fsupport;
import '../../support/party_host_reference.dart';

/// A simulated phone: its [PartySession] + a reference to both transports.
class SimClient {
  SimClient({
    required this.session,
    required this.clientTransport,
    required this.serverTransport,
  }) {
    session.states.listen(snapshots.add);
    session.events.listen(events.add);
  }

  final PartySession session;
  final InMemoryPartyTransport clientTransport;
  final InMemoryPartyTransport serverTransport;

  final List<PartyState> snapshots = [];
  final List<PartyEvent> events = [];

  PartyState get state => session.state;

  void join({required String name, String emoji = '🟢'}) =>
      session.joinRoom(playerName: name, emoji: emoji);

  void ready() => session.setReady(true);
  void unready() => session.setReady(false);
  void leave() => session.leaveRoom();

  void tap(String? targetId, {int? index}) =>
      session.sendAction(PartyAction.tap(targetId: targetId, index: index));

  void tapBackground() => session.sendAction(const PartyAction.tap());

  void commitCount(int n) => session.sendAction(PartyAction.count(n));

  /// Discovers the tap count that makes the rebuilt round challenge pass, by
  /// replaying the *same* canonical challenge through a [fsupport.FakeHost].
  /// This mirrors what the host judges, so it exercises the shared-rebuild
  /// contract (same `seed` → same `Challenge` → same correct answer).
  int? correctTapCount() {
    final round = state.round;
    if (round == null) return null;
    for (var n = 0; n <= 12; n++) {
      final ch = buildFromSeed(
        challengeId: round.challengeId,
        seed: round.seed,
        level: round.level,
      );
      final host = fsupport.FakeHost();
      ch.onStart(host);
      for (var i = 0; i < n; i++) {
        if (host.settled) break;
        ch.onTap(fsupport.tapOn('pad', at: const Duration(milliseconds: 500)), host);
      }
      fsupport.advance(ch, host, to: ch.duration);
      if (host.passed) return n;
    }
    return null;
  }

  /// The challenge id of the current local round, if any.
  String? get currentChallengeId => state.round?.challenge.id;

  /// Sends a raw line straight into the host (bypasses the session), for
  /// gatekeeper / malformed-input scenarios. Sending on the client transport
  /// delivers into the host's inbound listener.
  void sendRaw(String line) => clientTransport.send(line);

  T? lastEvent<T extends PartyEvent>() {
    for (final e in events.reversed) {
      if (e is T) return e;
    }
    return null;
  }
}

/// One host + its clock + every attached client.
class PartyHarness {
  PartyHarness({
    this.hostName = 'test-host',
    this.roomCode = 'ABC123',
    this.maxPlayers = 8,
    this.lives = 3,
    this.battleRounds = 20,
    this.speedBonus = false,
    this.graceWindowMs = 15000,
  }) : clock = FakePartyClock() {
    _host = PartyHostReference(
      hostName: hostName,
      roomCode: roomCode,
      maxPlayers: maxPlayers,
      lives: lives,
      battleRounds: battleRounds,
      speedBonus: speedBonus,
      graceWindowMs: graceWindowMs,
      clock: clock,
    );
  }

  /// Same as [PartyHarness] but the default, fixed-name constructor for a
  /// config-heavy test that wants to tweak the host directly.
  PartyHarness.fromConfig(PartyHostReference partHost, FakePartyClock clock)
      : clock = clock,
        hostName = partHost.hostName,
        roomCode = partHost.roomCode,
        maxPlayers = partHost.maxPlayers,
        lives = partHost.lives,
        battleRounds = partHost.battleRounds,
        speedBonus = partHost.speedBonus,
        graceWindowMs = partHost.graceWindowMs {
    _host = partHost;
  }

  final String hostName;
  final String roomCode;
  final int maxPlayers;
  final int lives;
  final int battleRounds;
  final bool speedBonus;
  final int graceWindowMs;

  final FakePartyClock clock;
  late PartyHostReference _host;
  final List<SimClient> clients = [];

  PartyHostReference get host => _host;

  SimClient addClient({required String name, String emoji = '🟢'}) {
    final (clientTransport, serverTransport) = InMemoryPartyTransport.pair();
    _host.attachClient(serverTransport);
    final session = PartySession(
      transport: clientTransport,
      appName: 'are-you-stupid-test',
      appVersion: '1.0.0',
    );
    final client = SimClient(
      session: session,
      clientTransport: clientTransport,
      serverTransport: serverTransport,
    );
    clients.add(client);
    client.session.connect();
    return client;
  }

  /// The challenge view a client rebuilt for the open round (or null).
  PartyRound? roundOf(SimClient client) => client.state.round;
}