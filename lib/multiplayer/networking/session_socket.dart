/// Real `dart:io` [Socket] transport — the production [PartyTransport].
///
/// A raw TCP socket is preferred over a WebSocket package because the host is
/// a plain TCP server ([[Multiplayer Protocol]] — "no new dependency"). The
/// wire is JSONL, so framing is just newline-delimited UTF-8 lines: [inbound]
/// decodes with [LineSplitter], [send] appends the newline itself.
///
/// Symmetric on purpose: the exact same class wraps a socket the Flutter
/// client opened with [Socket.connect] (the shipped join flow) and one a
/// host accepted from a [ServerSocket] (`tool/dev_multiplayer_host.dart`,
/// and later the Swift host's own socket handling doesn't need this file at
/// all — but any *Dart* host, like the dev tool, can reuse it as-is).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'party_transport.dart';

class SocketPartyTransport implements PartyTransport {
  SocketPartyTransport(this._socket) {
    _sub = _socket
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(
          _inbound.add,
          onDone: () => unawaited(_inbound.close()),
          onError: (Object _) => unawaited(_inbound.close()),
          cancelOnError: true,
        );
  }

  /// Connects to a host at [address]:[port]. Throws [SocketException] on
  /// failure — callers show a connection-error state, they don't retry
  /// blindly (see `mp_join_screen.dart`).
  static Future<SocketPartyTransport> connect(
    String address,
    int port, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final socket = await Socket.connect(address, port, timeout: timeout);
    socket.setOption(SocketOption.tcpNoDelay, true);
    return SocketPartyTransport(socket);
  }

  final Socket _socket;
  late final StreamSubscription<String> _sub;
  final _inbound = StreamController<String>.broadcast(sync: true);
  bool _closed = false;

  @override
  Stream<String> get inbound => _inbound.stream;

  @override
  void send(String line) {
    if (_closed) return;
    _socket.write('$line\n');
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _sub.cancel();
    await _inbound.close();
    await _socket.close();
  }
}
