import 'package:flutter_test/flutter_test.dart';
import 'package:are_you_stupid/multiplayer/presenter/spoken_identity.dart';

void main() {
  test('blocked-name taunts are varied but stable for the same name', () {
    final first = blockedNameTauntKey('c4zz0');
    expect(blockedNameTauntKey('c4zz0'), first);
    expect(
      {
        'c4zz0',
        'putt4n4',
        'n1gg4',
        'www.example.com',
      }.map(blockedNameTauntKey).toSet().length,
      greaterThan(1),
    );
    expect(first, matches(RegExp(r'^ui\.mp\.join\.nice_try_[1-5]$')));
  });

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

  test('common leetspeak is normalized before pronunciation', () {
    final identity = SpokenIdentity.classify(r'M4r10');
    expect(identity.spokenName, 'Mario');
    expect(identity.policy, NameSpeechPolicy.speakAlias);
  });

  test('leetspeak cannot bypass the profanity filter', () {
    expect(SpokenIdentity.classify(r'c4zz0').policy, NameSpeechPolicy.blocked);
  });

  test('an internal unknown symbol asks for AI refinement', () {
    expect(SpokenIdentity.classify('Lu☠ca').needsAi, isTrue);
  });

  test('low-confidence model aliases become display-only', () {
    final identity = SpokenIdentity.fromAi(
      displayName: 'Lu☠ca',
      decision: 'speakAlias',
      spokenName: 'Luca',
      confidence: 0.5,
    );
    expect(identity.policy, NameSpeechPolicy.displayOnly);
  });
}
