/// A local, deterministic first pass for presenter-safe player identity.
/// The optional on-device model may refine ambiguous cases later, but the
/// room never depends on model availability ([[Multiplayer Presenter]]).
enum NameSpeechPolicy {
  speakOriginal,
  speakAlias,
  displayOnly,
  blocked,
  uncertain,
}

const int blockedNameTauntCount = 5;

/// Keeps the presenter's rejection varied across players but stable across
/// rebuilds and devices. This is deliberately deterministic: UI copy must not
/// flicker while the player edits an otherwise unchanged name.
String blockedNameTauntKey(String displayName) {
  var hash = 0x811c9dc5;
  for (final unit in displayName.trim().toLowerCase().codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return 'ui.mp.join.nice_try_${(hash % blockedNameTauntCount) + 1}';
}

class SpokenIdentity {
  const SpokenIdentity({
    required this.displayName,
    required this.policy,
    this.spokenName,
  });

  final String displayName;
  final String? spokenName;
  final NameSpeechPolicy policy;

  bool get needsAi => policy == NameSpeechPolicy.uncertain;

  static const _leet = <String, String>{
    '0': 'o',
    '1': 'i',
    '2': 'z',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '6': 'g',
    '7': 't',
    '8': 'b',
    '9': 'g',
    '@': 'a',
    r'$': 's',
    '!': 'i',
  };

  static const _blockedTerms = <String>{
    'nigger',
    'nigga',
    'frocio',
    'negro',
    'puttana',
    'cazzo',
  };

  static SpokenIdentity classify(String raw) {
    final display = raw.trim().replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), '');
    if (display.isEmpty) {
      return const SpokenIdentity(
        displayName: '',
        policy: NameSpeechPolicy.blocked,
      );
    }
    final folded = _foldLeet(display.toLowerCase());
    if (_blockedTerms.any((term) => folded.contains(term)) ||
        RegExp(r'https?://|www\.|@.+\.').hasMatch(display.toLowerCase())) {
      return SpokenIdentity(
        displayName: display,
        policy: NameSpeechPolicy.blocked,
      );
    }

    // Gamer-tag "x" wrappers ("xXLucaXx", "x Luca x") are dropped, but only
    // when they are clearly decoration: a run of 2-3 on both sides, or a run
    // set apart by a space/underscore. A bare edge "x" belongs to the name —
    // ALEX, MAX, FELIX, XAVIER must keep it.
    var candidate = display.replaceAll('_', ' ');
    final wrapped = RegExp(r'^[xX]{2,3}(.+?)[xX]{2,3}$').firstMatch(candidate);
    if (wrapped != null) candidate = wrapped.group(1)!;
    candidate = candidate
        .replaceAll(RegExp(r'^[xX]{1,3}\s+'), '')
        .replaceAll(RegExp(r'\s+[xX]{1,3}$'), '')
        .replaceAll(RegExp(r"^[^\p{L}\p{M}\p{N}]+", unicode: true), '')
        .replaceAll(RegExp(r"[^\p{L}\p{M}\p{N}]+$", unicode: true), '');
    candidate = _foldLeet(candidate)
        .replaceAll(RegExp(r"[^\p{L}\p{M}'’\- ]", unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (candidate.isEmpty || candidate.length > 30) {
      return SpokenIdentity(
        displayName: display,
        policy: NameSpeechPolicy.displayOnly,
      );
    }
    if (RegExp(
      r"\p{L}[^\p{L}\p{M}\p{N}_'’\-]\p{L}",
      unicode: true,
    ).hasMatch(display)) {
      return SpokenIdentity(
        displayName: display,
        spokenName: candidate,
        policy: NameSpeechPolicy.uncertain,
      );
    }
    final changed = candidate != display;
    return SpokenIdentity(
      displayName: display,
      spokenName: candidate,
      policy: changed
          ? NameSpeechPolicy.speakAlias
          : NameSpeechPolicy.speakOriginal,
    );
  }

  static String _foldLeet(String value) =>
      value.split('').map((char) => _leet[char] ?? char).join();

  static SpokenIdentity fromAi({
    required String displayName,
    required String decision,
    String? spokenName,
    required double confidence,
  }) {
    if (confidence < 0.72 || decision == 'uncertain') {
      return SpokenIdentity(
        displayName: displayName,
        policy: NameSpeechPolicy.displayOnly,
      );
    }
    final alias = spokenName?.trim().replaceAll(
      RegExp(r"[^\p{L}\p{M}'’\- ]", unicode: true),
      '',
    );
    if (decision == 'blocked') {
      return SpokenIdentity(
        displayName: displayName,
        policy: NameSpeechPolicy.blocked,
      );
    }
    if (decision == 'displayOnly' ||
        alias == null ||
        alias.isEmpty ||
        alias.length > 30) {
      return SpokenIdentity(
        displayName: displayName,
        policy: NameSpeechPolicy.displayOnly,
      );
    }
    return SpokenIdentity(
      displayName: displayName,
      spokenName: alias,
      policy: decision == 'speakOriginal'
          ? NameSpeechPolicy.speakOriginal
          : NameSpeechPolicy.speakAlias,
    );
  }
}
