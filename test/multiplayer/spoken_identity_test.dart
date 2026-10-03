import 'package:flutter_test/flutter_test.dart';
import 'package:are_you_stupid/multiplayer/presenter/spoken_identity.dart';

void main() {
  test('extracts a speakable alias from a decorated name', () {
    final identity = SpokenIdentity.classify(r'x_$Luca🔥_xX');
    expect(identity.displayName, r'x_$Luca🔥_xX');
    expect(identity.spokenName, 'Luca');
    expect(identity.policy, NameSpeechPolicy.speakAlias);
  });

  test('keeps a plain name unchanged', () {
    final identity = SpokenIdentity.classify('Giulia');
    expect(identity.spokenName, 'Giulia');
    expect(identity.policy, NameSpeechPolicy.speakOriginal);
  });

  test('emoji-only names stay display-only', () {
    expect(
      SpokenIdentity.classify('🔥💀').policy,
      NameSpeechPolicy.displayOnly,
    );
  });

  test('obvious unsafe input is blocked before any model call', () {
    expect(
      SpokenIdentity.classify('www.example.com').policy,
      NameSpeechPolicy.blocked,
    );
  });
}
