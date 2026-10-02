// Pure matching-rule tests for LanPartyDiscovery — the real discovery I/O
// needs a live network, a real advertiser (the tvOS/macOS host) and the
// native NsdManager/NSNetServiceBrowser plumbing `package:nsd` wraps, so
// this only proves the part that's testable headless: which discovered
// service name is "ours" for a given room code. See
// [[Multiplayer Development]], [[Decision Log]].
import 'dart:convert';
import 'dart:io';

import 'package:are_you_stupid/multiplayer/networking/lan_discovery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsd/nsd.dart';

void main() {
  group('matchesRoomCode', () {
    test('matches the exact instance name', () {
      expect(matchesRoomCode('7F4K', '7F4K'), isTrue);
    });

    test('is case-insensitive on both sides', () {
      expect(matchesRoomCode('7f4k', '7F4K'), isTrue);
      expect(matchesRoomCode('7F4K', '7f4k'), isTrue);
    });

    test('trims whitespace on both sides', () {
      expect(matchesRoomCode(' 7F4K ', '7F4K'), isTrue);
      expect(matchesRoomCode('7F4K', ' 7F4K '), isTrue);
    });

    test('rejects a different room code', () {
      expect(matchesRoomCode('9XQ2', '7F4K'), isFalse);
    });

    test('rejects a prefix collision that is not an exact match', () {
      // "7F4K1" must not match room "7F4K".
      expect(matchesRoomCode('7F4K1', '7F4K'), isFalse);
    });

    test('rejects a null service name', () {
      expect(matchesRoomCode(null, '7F4K'), isFalse);
    });
  });

  group('candidateFromService', () {
    test('reads the host card metadata from Bonjour TXT', () {
      final candidate = candidateFromService(
        Service(
          name: '7F4K',
          host: 'living-room.local.',
          port: 4242,
          addresses: [InternetAddress.loopbackIPv4],
          txt: {
            'room': utf8.encode('7F4K'),
            'name': utf8.encode('Living Room TV'),
            'players': utf8.encode('3'),
            'max': utf8.encode('8'),
            'state': utf8.encode('lobby'),
          },
        ),
      );
      expect(candidate, isNotNull);
      expect(candidate!.displayName, 'Living Room TV');
      expect(candidate.playerCount, 3);
      expect(candidate.maxPlayers, 8);
      expect(candidate.roomCode, '7F4K');
      expect(candidate.canJoin, isTrue);
    });

    test('marks a running room as visible but not joinable', () {
      final candidate = candidateFromService(
        Service(
          name: 'ABCD',
          port: 4242,
          addresses: [InternetAddress.loopbackIPv4],
          txt: {'state': utf8.encode('playing')},
        ),
      );
      expect(candidate, isNotNull);
      expect(candidate!.canJoin, isFalse);
    });

    test('supports an older host without TXT metadata', () {
      final candidate = candidateFromService(
        Service(
          name: 'OLD1',
          host: 'old-apple-tv.local.',
          port: 4242,
          addresses: [InternetAddress.loopbackIPv4],
        ),
      );
      expect(candidate, isNotNull);
      expect(candidate!.roomCode, 'OLD1');
      expect(candidate.maxPlayers, 8);
      expect(candidate.canJoin, isTrue);
    });
  });
}
