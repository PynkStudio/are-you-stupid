/// Shared simulation harness for the multiplayer suites.
///
/// Wires one [PartyHostReference] to any number of [PartySession]s over
/// in-memory transports, all under one deterministic [FakePartyClock]
/// ([[Multiplayer Development]]). Streams are synchronous (broadcast with
/// `sync: true`), so snapshots fill the moment a message is handled — tests
/// never sleep.
library;

import 'package:are_you_stupid/challenges/registry.dart';
import 'package:are_you_stupid/core/challenge.dart';
import 'package:are_you_stupid/multiplayer/engine/party_session.dart';
import 'package:are_you_stupid/multiplayer/engine/party_state.dart';
import 'package:are_you_stupid/multiplayer/networking/party_transport.dart';

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

  /// Submits one tap the same way a real phone does: through
  /// `PartySession.submitTap`, into the session's own `PartyChallengeRunner`
  /// — which judges it (the client-side verdict, per the design-change note
  /// on `PlayerAction`) and sends the resulting `PLAYER_ACTION` itself. This
  /// only does anything once GO has actually reached the client; the
  /// harness's synchronous transports mean that's already true by the time
  /// a test can call this right after `host.startRound(...)`.
  ///
  /// Some templates don't decide on the tap itself — a counting challenge's
  /// "settle" grace window (`lib/challenges/counting_challenges.dart`) only
  /// resolves on a later `onTick`. A real phone gets there by a `Ticker`
  /// running over real time; this fast-forwards `PartySession.tick` the same
  /// way `FakePartyClock.advance` stands in for the host's clock, so the
  /// test doesn't have to actually wait.
  void tap(String? targetId, {int? index}) {
    _rawTap(targetId, index: index);
    _driveToSettleOrTimeout();
  }

  void tapBackground() => tap(null);

  /// Simulates committing a count for a counting-family challenge
  /// (`tap_exactly_n`, `tap_twice`, …) the way the real renderer would: `n`
  /// individual taps on the challenge's one target, letting the `Challenge`
  /// itself track the running count and decide pass/fail — see
  /// `lib/challenges/counting_challenges.dart`'s `ExactTapsChallenge.onTap`.
  /// Only the *last* tap fast-forwards to settle/timeout (via [tap]'s
  /// driving) — an intermediate tap must stay raw, or the settle loop would
  /// run all the way to timeout after the very first of the `n` taps,
  /// since nothing but the *final* count actually decides the round.
  void commitCount(int n) {
    for (var i = 0; i < n - 1; i++) {
      _rawTap('pad');
    }
    if (n > 0) {
      tap('pad');
    } else {
      _driveToSettleOrTimeout();
    }
  }

  void _rawTap(String? targetId, {int? index}) => session.submitTap(TapInfo(
        targetId: targetId,
        elapsed: session.runnerElapsed ?? Duration.zero,
        index: index,
      ));

  /// Simulates a player who never answers: fast-forwards straight to the
  /// challenge's own timeout, exactly like `tap`'s settle fast-forward but
  /// with no input at all first. This is what a real client does on its own
  /// once its local clock reaches the round's `durationMs` — the host's own
  /// timeout fallback (always "wrong", [[Decision Log]]) is only for a
  /// client that goes fully silent (disconnected/crashed), which this is
  /// deliberately *not* simulating.
  void letRoundTimeOut() => _driveToSettleOrTimeout();

  /// The test-side equivalent of a real per-frame `Ticker`: advances
  /// `PartySession.tick` in fixed steps until this player's `RoundResult`
  /// arrives (the host round-trips synchronously over the harness's
  /// in-memory transports) or the challenge's own duration is exhausted.
  void _driveToSettleOrTimeout({Duration step = const Duration(milliseconds: 16)}) {
    final round = state.round;
    if (round == null) return;
    var elapsed = session.runnerElapsed ?? Duration.zero;
    while (state.privateResult == null && elapsed < round.challenge.duration) {
      elapsed += step;
      session.tick(elapsed);
    }
  }

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