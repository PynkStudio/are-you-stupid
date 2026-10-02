// Pure matching-rule tests for LanPartyDiscovery — the real discovery I/O
// needs a live network, a real advertiser (the tvOS/macOS host) and the
// native NsdManager/NSNetServiceBrowser plumbing `package:nsd` wraps, so
// this only proves the part that's testable headless: which discovered
// service name is "ours" for a given room code. See
// [[Multiplayer Development]], [[Decision Log]].
import 'package:are_you_stupid/multiplayer/networking/lan_discovery.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
