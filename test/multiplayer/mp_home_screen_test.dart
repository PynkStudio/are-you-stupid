// roomCodeFromScannedValue is the only pure logic in mp_home_screen.dart
// (everything else is widgets needing a live camera/MobileScanner) — see
// [[Multiplayer Client (Mobile)]].
import 'package:are_you_stupid/ui/screens/multiplayer/mp_home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('roomCodeFromScannedValue', () {
    test('extracts the room code from a valid deep link', () {
      expect(roomCodeFromScannedValue('areyoustupid://join?room=7f4k'), '7F4K');
    });

    test('uppercases the extracted code', () {
      expect(roomCodeFromScannedValue('areyoustupid://join?room=abcd'), 'ABCD');
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
      expect(
        roomCodeFromScannedValue('areyoustupid://join?room=7F4KK'),
        isNull,
      );
    });

    test(
      'extracts the room code from the universal link the TV/Mac QR shows',
      () {
        expect(
          roomCodeFromScannedValue('https://pynkstudio.eu/ays/join?room=7f4k'),
          '7F4K',
        );
        expect(
          roomCodeFromScannedValue(
            'https://www.pynkstudio.eu/ays/join/?room=AB3D',
          ),
          'AB3D',
        );
      },
    );

    test('rejects https links on another host or path', () {
      expect(
        roomCodeFromScannedValue('https://evil.example/ays/join?room=7F4K'),
        isNull,
      );
      expect(
        roomCodeFromScannedValue('http://pynkstudio.eu/ays/join?room=7F4K'),
        isNull,
      );
      expect(
        roomCodeFromScannedValue('https://pynkstudio.eu/join?room=7F4K'),
        isNull,
      );
    });

    test('returns null for the wrong scheme', () {
      expect(roomCodeFromScannedValue('otherapp://join?room=7F4K'), isNull);
    });
  });

  group('joinTargetFromScannedValue', () {
    test('reads the direct-connect hint from the QR link', () {
      final target = joinTargetFromScannedValue(
        'https://pynkstudio.eu/ays/join?room=7f4k&h=192.168.1.20:54321',
      );
      expect(target?.roomCode, '7F4K');
      expect(target?.directHost, '192.168.1.20:54321');
    });

    test('a link without a hint still joins by Bonjour', () {
      final target = joinTargetFromScannedValue(
        'https://pynkstudio.eu/ays/join?room=7F4K',
      );
      expect(target?.roomCode, '7F4K');
      expect(target?.directHost, isNull);
    });

    test('an out-of-range hint is dropped, the room code kept', () {
      final target = joinTargetFromScannedValue(
        'https://pynkstudio.eu/ays/join?room=7F4K&h=300.1.1.1:99999',
      );
      expect(target?.roomCode, '7F4K');
      expect(target?.directHost, isNull);
    });

    test('rejects a non-numeric hint host', () {
      expect(
        joinTargetFromScannedValue(
          'https://pynkstudio.eu/ays/join?room=7F4K&h=evil.example:80',
        ),
        isNull,
      );
    });
  });
}
