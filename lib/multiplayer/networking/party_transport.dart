/// Multiplayer networking abstraction — pure Dart.
///
/// Phase 2 keeps networking headless: [PartyTransport] is the only seam both
/// engines depend on. The in-process pair ([InMemoryPartyTransport]) powers
/// the simulation harness; real dart:io sockets and Bonjour arrive in later
/// phases ([[Multiplayer Client (Mobile)]], `networking/session_socket.dart`).
library;

import 'dart:async';

/// A line-based duplex channel between two ends.
///
/// The wire format is JSONL (one JSON object per UTF-8 line) exactly as
/// [[Multiplayer Protocol]] defines. [send] delivers a whole line to the
/// remote end; [inbound] yields the lines the remote end sent. When the
/// remote end closes, [inbound] completes.
abstract class PartyTransport {
  /// Lines received from the remote end.
  Stream<String> get inbound;

  /// Sends one complete line. `line` must not contain a newline.
  void send(String line);

  /// Closes this end of the channel. The remote end's [inbound] completes.
  Future<void> close();
}

/// A pair of transports wired together in one process — the in-memory
/// stand-in for a TCP connection, used by the simulation harness and every
/// headless test ([[Multiplayer Development]]).
class InMemoryPartyTransport implements PartyTransport {
  InMemoryPartyTransport._(this._peer);

  /// Always bound to a real peer by [pair] before any use.
  InMemoryPartyTransport? _peer;
  bool _closed = false;
  final _inbound = StreamController<String>.broadcast(sync: true);

  /// Creates a fresh connected pair of transports.
  static (InMemoryPartyTransport, InMemoryPartyTransport) pair() {
    final a = InMemoryPartyTransport._(null);
    final b = InMemoryPartyTransport._(a);
    a._peer = b;
    return (a, b);
  }

  bool get isClosed => _closed;

  /// The peer end of this pair (for tests that need to inspect both sides).
  InMemoryPartyTransport get peer => _peer!;

  @override
  Stream<String> get inbound => _inbound.stream;

  @override
  void send(String line) {
    if (_closed) {
      throw StateError('transport is closed');
    }
    _peer!.deliver(line);
  }

  void deliver(String line) {
    if (_closed) return;
    _inbound.add(line);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    // Signal the remote end that this side went away.
    unawaited(_peer!._inbound.close());
    await _inbound.close();
  }

  /// Delivers an opaque stream-end to the remote end while keeping this side
  /// usable — simulates the network vanishing without closing locally.
  Future<void> simulateDroppedPeer() async {
    final peer = _peer;
    if (peer == null || peer._closed) return;
    await peer._inbound.close();
  }
}

/// A synchronized monotonic clock used by headless host tests so time can be
/// advanced deterministically instead of sleeping ([[Multiplayer Development]]).
class FakePartyClock {
  FakePartyClock([this._nowMs = 0]);

  int _nowMs;
  int get nowMs => _nowMs;

  void advance(int ms) => _nowMs += ms;
}