// roomCodeFromScannedValue is the only pure logic in mp_home_screen.dart
// (everything else is widgets needing a live camera/MobileScanner) — see
// [[Multiplayer Client (Mobile)]].
import 'package:are_you_stupid/ui/screens/multiplayer/mp_home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('roomCodeFromScannedValue', () {
    test('extracts the room code from a valid deep link', () {
      expect(
        roomCodeFromScannedValue('areyoustupid://join?room=7f4k'),
        '7F4K',
      );
    });

    test('uppercases the extracted code', () {
      expect(
        roomCodeFromScannedValue('areyoustupid://join?room=abcd'),
        'ABCD',
      );
    });

    test('trims surrounding whitespace before matching', () {
      expect(
        roomCodeFromScannedValue('  areyoustupid://join?room=7F4K  '),
        '7F4K',
      );
    });

    test('returns null for null input', () {
      expect(roomCodeFromScannedValue(null), isNull);
    });

    test('returns null for an unrelated QR payload', () {
      expect(roomCodeFromScannedValue('https://example.com'), isNull);
    });

    test('returns null for a code that is not exactly 4 characters', () {
      expect(roomCodeFromScannedValue('areyoustupid://join?room=7F4'), isNull);
      expect(roomCodeFromScannedValue('areyoustupid://join?room=7F4KK'), isNull);
    });

    test('returns null for the wrong scheme', () {
      expect(roomCodeFromScannedValue('otherapp://join?room=7F4K'), isNull);
    });
  });
}
