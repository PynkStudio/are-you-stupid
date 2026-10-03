/// A local, deterministic first pass for presenter-safe player identity.
/// The optional on-device model may refine ambiguous cases later, but the
/// room never depends on model availability ([[Multiplayer Presenter]]).
enum NameSpeechPolicy { speakOriginal, speakAlias, displayOnly, blocked }

class SpokenIdentity {
  const SpokenIdentity({
    required this.displayName,
    required this.policy,
    this.spokenName,
  });

  final String displayName;
  final String? spokenName;
  final NameSpeechPolicy policy;

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
    final lower = display.toLowerCase();
    if (_blockedTerms.any((term) => lower.contains(term)) ||
        RegExp(r'https?://|www\.|@.+\.').hasMatch(lower)) {
      return SpokenIdentity(
        displayName: display,
        policy: NameSpeechPolicy.blocked,
      );
    }

    var candidate = display
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'^[xX]{1,3}\s*'), '')
        .replaceAll(RegExp(r'\s*[xX]{1,3}$'), '')
        .replaceAll(RegExp(r"[^\p{L}\p{M}'’\- ]", unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (candidate.isEmpty || candidate.length > 30) {
      return SpokenIdentity(
        displayName: display,
        policy: NameSpeechPolicy.displayOnly,
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
}
