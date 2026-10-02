// Real loopback TCP round-trip for SocketPartyTransport — the one piece of
// Phase 3 networking every other multiplayer suite still fakes via
// InMemoryPartyTransport. See [[Multiplayer Development]].
import 'dart:async';
import 'dart:io';

import 'package:are_you_stupid/multiplayer/networking/session_socket.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SocketPartyTransport', () {
    late ServerSocket server;

    setUp(() async {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    });

    tearDown(() async {
      await server.close();
    });

    test('delivers lines sent from the other end', () async {
      final serverSideDone = Completer<SocketPartyTransport>();
      server.listen((socket) {
        serverSideDone.complete(SocketPartyTransport(socket));
      });

      final client = await SocketPartyTransport.connect(
        InternetAddress.loopbackIPv4.address,
        server.port,
      );
      final serverSide = await serverSideDone.future;

      final received = <String>[];
      final sub = serverSide.inbound.listen(received.add);

      client.send('{"type":"HELLO"}');
      client.send('{"type":"JOIN_ROOM"}');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(received, ['{"type":"HELLO"}', '{"type":"JOIN_ROOM"}']);

      await sub.cancel();
      await client.close();
      await serverSide.close();
    });

    test('is bidirectional', () async {
      final serverSideDone = Completer<SocketPartyTransport>();
      server.listen((socket) {
        serverSideDone.complete(SocketPartyTransport(socket));
      });

      final client = await SocketPartyTransport.connect(
        InternetAddress.loopbackIPv4.address,
        server.port,
      );
      final serverSide = await serverSideDone.future;

      final clientReceived = <String>[];
      final sub = client.inbound.listen(clientReceived.add);

      serverSide.send('{"type":"HOST_HELLO"}');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(clientReceived, ['{"type":"HOST_HELLO"}']);

      await sub.cancel();
      await client.close();
      await serverSide.close();
    });

    test('inbound completes when the remote end closes', () async {
      final serverSideDone = Completer<SocketPartyTransport>();
      server.listen((socket) {
        serverSideDone.complete(SocketPartyTransport(socket));
      });

      final client = await SocketPartyTransport.connect(
        InternetAddress.loopbackIPv4.address,
        server.port,
      );
      final serverSide = await serverSideDone.future;

      final done = client.inbound.isEmpty; // completes when inbound closes.
      await serverSide.close();
      await done;

      await client.close();
    });

    test('send() after close() is a safe no-op', () async {
      final client = await SocketPartyTransport.connect(
        InternetAddress.loopbackIPv4.address,
        server.port,
      );
      await client.close();
      expect(() => client.send('{"type":"LEAVE_ROOM"}'), returnsNormally);
    });

    test('connect() throws for a port nothing is listening on', () async {
      // Bind-and-immediately-close to get a port that's very likely free.
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final freePort = probe.port;
      await probe.close();

      expect(
        () => SocketPartyTransport.connect(
          InternetAddress.loopbackIPv4.address,
          freePort,
          timeout: const Duration(seconds: 1),
        ),
        throwsA(isA<SocketException>()),
      );
    });
  });
}
