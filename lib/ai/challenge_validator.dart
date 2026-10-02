/// ChallengeValidator — the deterministic gate between the model and the
/// player ([[AI Challenge Validator]]).
///
/// Pure Dart, zero model dependencies, stateless and deterministic: the same
/// proposal + the same context ⇒ the same verdict, every time. That property
/// is what lets the pre-generation cache trust it and lets the multiplayer
/// host and phones agree on a bad round.
///
/// The validator is the authority. Nothing the model writes can make the game
/// unplayable; a proposal that fails validation is never served. It does not
/// tune difficulty, render, localize, or judge fun.
///
/// This file is PURE DART: no Flutter imports.
library;

import '../core/difficulty.dart';
import '../i18n/app_locale.dart';
import 'challenge_vocabulary.dart';
import 'generated_challenge.dart';

/// The outcome of one validation pass, first failure wins, in check order.
sealed class ChallengeVerdict {
  const ChallengeVerdict();
}

/// Playable — serve it.
class VerdictValid extends ChallengeVerdict {
  const VerdictValid();
}

/// Statically unplayable: the engine cannot render or judge it (unknown
/// mechanic / shape / color / trick / source). Not retryable by construction;
/// the cache drops it silently and the engine stays on scripted.
class VerdictExitChallenge extends ChallengeVerdict {
  const VerdictExitChallenge();
}

/// Structurally fixable by one regeneration (instruction too long, lowercase,
/// empty instruction ...). The prefetch loop regenerates exactly once, then
/// the unit is a [VerdictFailureExit].
class VerdictRetryableForcedExit extends ChallengeVerdict {
  const VerdictRetryableForcedExit();
}

/// Contradicts the pillars or the mechanic's contract. Carries [retryable]:
/// content the model can fix by trying again vs. content that must not be
/// played under any wording.
class VerdictInvalid extends ChallengeVerdict {
  const VerdictInvalid(this.reason, {this.retryable = true});

  /// Machine-readable reason, e.g. `bounds.opacity`.
  final String reason;

  /// Whether one regeneration may fix it.
  final bool retryable;
}

/// The model is producing garbage (persistent env failure, tone bans): stop
/// asking this unit. Next prefetch units continue normally.
class VerdictFailureExit extends ChallengeVerdict {
  const VerdictFailureExit();
}

/// Stamp of what was actually served recently, for the freshness check.
/// The Director builds stamps for scripted AND AI rounds (Phase 5) — a
/// generated near-duplicate of a just-played scripted challenge is rejected
/// exactly like a duplicate of another AI round
/// ([[AI Challenge Generation]] → «source ancestry and dedupe»).
class ServedChallengeStamp {
  const ServedChallengeStamp({
    required this.mechanic,
    required this.decoySignature,
  });

  /// The mechanic move that was served.
  final String mechanic;

  /// Deterministic signature of the decoys that were played.
  final String decoySignature;

  factory ServedChallengeStamp.ofProposal(ChallengeProposal p) =>
      ServedChallengeStamp(
        mechanic: p.mechanic.move,
        decoySignature: _decoySignature(p),
      );

  static String _decoySignature(ChallengeProposal p) {
    final correct = p.correctElement;
    final decoys = [...p.elements]..remove(correct);
    decoys.sort((a, b) => a.id.compareTo(b.id));
    final tokens = <String>[];
    for (final d in decoys) {
      tokens.add('${d.id}:${d.colorName}|${d.label}|${d.shapeName}'
          '|${_fmt(d.scale)}|${_fmt(d.rotation)}|${_fmt(d.opacity)}'
          '|${_fmt(d.dx)},${_fmt(d.dy)}');
    }
    return tokens.join(';');
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

/// Everything beyond the proposal itself that a validation pass needs.
class ValidationContext {
  const ValidationContext({
    required this.level,
    required this.locale,
    this.allowTricks = false,
    this.recentServed = const [],
  });

  /// The round number the challenge will be played at. Gates the time floor
  /// (via [Difficulty.speedForLevel]) exactly like scripted challenges.
  final int level;

  /// The player's language — the fail line must exist for it, it is the
  /// language the model was asked to write in, and it picks the text
  /// allowlist, word cap and imperative verbs.
  final AppLocale locale;

  /// Mirror of [Difficulty.allowsTricks] at [level].
  final bool allowTricks;

  /// The last few served rounds (scripted or AI), newest-last.
  final List<ServedChallengeStamp> recentServed;
}

/// ASCII allowlist for every string field a proposal carries: letters,
/// digits, spaces and `` `',.!?-_ `` only. Rejects control characters, emoji
/// and non-latin punctuation — the "no AI-ASCII embedding" guardrail
/// ([[Quality Neutrality and Guardrails]]).
final RegExp kAsciiAllowlist = RegExp(r"^[A-Za-z0-9 ,.!?\-_`']+$");

/// Absolute bans: profanity beyond the game's own roasts, self-harm,
/// hate figures, and real, unambiguous proper-noun personalities. Any hit →
/// [VerdictFailureExit]. Common nouns that *are* gameplay words ("APPLE")
/// are deliberately not banned — the model's own [`guardrailViolation`]
/// handling and the Phase 6 guardrail profiles catch the rest
/// ([[Foundation Models Integration]] → errors, [[Dynamic Profiles and Tool
/// Calling]]).
const Set<String> kForbiddenTokens = {
  'nigger',
  'faggot',
  'retard',
  'rape',
  'kill yourself',
  'suicide',
  'hitler',
  'nazi',
  'trump',
  'biden',
  'musk',
};

/// Meta-instructions that reference the AI — the game never explains itself
/// as a model ([[Quality Neutrality and Guardrails]] → "no AI wallpaper").
/// Exact-token match (case-insensitive), so "PAIR" ≠ "AI" but the concept is
/// caught. Retryable: regeneration can reword it.
const Set<String> kMetaAiTokens = {'ai', 'model', 'generated', 'machine'};

/// Player-facing text in a non-English locale (instruction, labels, fail
/// line, commentary) may use any Latin-script letter (accents, `ß`, `ç`),
/// the typographic apostrophe and Spanish opening marks — nothing else.
/// Ids and enum names stay [kAsciiAllowlist] in every locale.
final RegExp kLatinAllowlist =
    RegExp(r"^[\p{Script=Latin}0-9 ,.!?¡¿\-_`'’]+$", unicode: true);

/// The allowlist for player-facing text in [locale].
RegExp textAllowlistFor(AppLocale locale) =>
    locale == AppLocale.en ? kAsciiAllowlist : kLatinAllowlist;

/// Extra bans for the non-English locales, kept unambiguous on purpose (no
/// colour or timing words that a reflex game legitimately uses).
const Set<String> kForbiddenTokensLocalized = {
  'suicid',
  'suizid',
  'frocio',
  'maricón',
  'schwuchtel',
};

/// "The AI made this" in the six game languages.
const Set<String> kMetaAiTokensLocalized = {
  'ia',
  'ki',
  'modello',
  'modèle',
  'modelo',
  'modell',
  'generato',
  'généré',
  'generado',
  'gerado',
  'generiert',
};

/// Unicode-aware word split for the tone checks (`è`, `ß` stay inside words).
final RegExp _kNonWord = RegExp(r"[^\p{L}']+", unicode: true);

class ChallengeValidator {
  const ChallengeValidator();

  /// First-failing verdict in check order; [VerdictValid] when nothing fails.
  ChallengeVerdict validate(ChallengeProposal p, ValidationContext ctx) {
    final v = _envelope(p, ctx) ??
        _instruction(p, ctx) ??
        _mechanicContract(p, ctx) ??
        _elementBounds(p) ??
        _timeFloor(p, ctx) ??
        _decoyHonesty(p) ??
        _freshness(p, ctx) ??
        _resolvability(p) ??
        _tone(p);
    return v ?? const VerdictValid();
  }

  // 1. Envelope -------------------------------------------------------------

  ChallengeVerdict? _envelope(ChallengeProposal p, ValidationContext ctx) {
    if (!RegExp(r'^ai\.[a-z0-9]{5}$').hasMatch(p.id)) {
      return const VerdictInvalid('envelope.id');
    }
    if (p.instruction.trim().isEmpty) {
      return const VerdictRetryableForcedExit();
    }
    if (p.correctAnswer.elementId.isEmpty) {
      return const VerdictInvalid('envelope.correctAnswer');
    }
    if (p.source != 'ai') {
      return const VerdictExitChallenge();
    }
    if (p.elements.isEmpty || p.mechanic.move.isEmpty) {
      return const VerdictExitChallenge();
    }
    // The fail line must exist for the language the player is playing in.
    final line = p.failLine[ctx.locale.name] ?? '';
    if (line.trim().isEmpty) {
      return const VerdictInvalid('envelope.failLine');
    }
    // Player-facing text: the locale's allowlist (Latin script outside
    // English); ids and enum names: strict ASCII everywhere.
    final text = textAllowlistFor(ctx.locale);
    final texts = <String>[
      p.instruction,
      ...p.failLine.values,
      for (final e in p.elements) e.label,
    ];
    for (final s in texts) {
      if (!text.hasMatch(s)) {
        return const VerdictInvalid('envelope.ascii');
      }
    }
    final strings = <String>[
      p.mechanic.move,
      p.mechanic.action,
      p.mechanic.kind,
      ...p.mechanic.senseDecoys,
    ];
    for (final e in p.elements) {
      strings.add(e.id);
      strings.add(e.colorName);
      strings.add(e.shapeName);
    }
    for (final s in strings) {
      if (!kAsciiAllowlist.hasMatch(s)) {
        return const VerdictInvalid('envelope.ascii');
      }
    }
    return null;
  }

  // 2. Instruction rule -----------------------------------------------------

  ChallengeVerdict? _instruction(ChallengeProposal p, ValidationContext ctx) {
    final words = p.instruction.trim().split(RegExp(r'\s+'));
    // Under 8 words is the law in English; wordier languages get up to 10
    // and extra time for it ([localeTimeBonusMs]).
    if (words.length > instructionMaxWords(ctx.locale)) {
      return const VerdictRetryableForcedExit();
    }
    if (p.instruction.contains(RegExp(r'\p{Ll}', unicode: true))) {
      return const VerdictRetryableForcedExit(); // uppercase on screen
    }
    final contract = p.mechanicContract;
    if (contract != null) {
      final upper = p.instruction.toUpperCase();
      if (!contract.action.imperativeVerbsFor(ctx.locale).any(upper.contains)) {
        return VerdictInvalid('instruction.verb');
      }
    }
    return null;
  }

  // 3. Mechanic contract ----------------------------------------------------

  ChallengeVerdict? _mechanicContract(ChallengeProposal p, ValidationContext ctx) {
    if (p.mechanicContract == null) {
      return const VerdictExitChallenge(); // not in the vocabulary
    }
    final mech = p.mechanicContract!;
    if (AiAction.parse(p.mechanic.action) != mech.action) {
      return VerdictInvalid('mechanic.action');
    }
    if (p.mechanic.kind.isNotEmpty && AiKind.parse(p.mechanic.kind) != mech.kind) {
      return VerdictInvalid('mechanic.kind');
    }
    if (p.elements.length < mech.minElements || p.elements.length > mech.maxElements) {
      return VerdictInvalid('mechanic.elements');
    }
    final trick = p.difficulty.trickType;
    if (trick == null) {
      return const VerdictExitChallenge(); // unrenderable trick
    }
    if (mech.requiresTrick) {
      if (trick.isNone || !ctx.allowTricks) {
        return VerdictInvalid('mechanic.trickRequired');
      }
    } else if (!ctx.allowTricks) {
      // Only `none` and the gentle `swap` exist before tricks unlock
      // ([[Difficulty Curve]] ladder).
      if (trick != AiTrickType.none && trick != AiTrickType.swap) {
        return VerdictInvalid('mechanic.trickNotAllowed');
      }
    }
    if (!trick.isNone && !mech.allowedTricks.contains(trick)) {
      return VerdictInvalid('mechanic.trickComposition');
    }
    // Declared sense decoys must correspond to real differences somewhere.
    final correct = p.correctElement;
    if (correct != null) {
      final dims = <AiSenseDecoy>{};
      for (final e in p.elements) {
        if (e == correct) continue;
        _dimsDiffering(correct, e, dims);
      }
      for (final d in mech.senseDecoys) {
        if (!dims.contains(d)) {
          return VerdictInvalid('mechanic.senseDecoys');
        }
      }
    }
    return null;
  }

  // 4. Element bounds -------------------------------------------------------

  ChallengeVerdict? _elementBounds(ChallengeProposal p) {
    if (p.elements.length < 2 || p.elements.length > 6) {
      return VerdictInvalid('bounds.count');
    }
    for (final e in p.elements) {
      if (e.scale < 0.45 || e.scale > 2.0) return VerdictInvalid('bounds.scale');
      if (e.opacity < 0.35 || e.opacity > 1.0) {
        return VerdictInvalid('bounds.opacity');
      }
      if (e.rotation.abs() > 0.6) return VerdictInvalid('bounds.rotation');
      if (e.dx.abs() > 0.6 || e.dy.abs() > 0.6) {
        return VerdictInvalid('bounds.offset');
      }
      if (e.shape == null || e.color == null) {
        return const VerdictExitChallenge(); // engine cannot render it
      }
    }
    return null;
  }

  // 5. Time floor -----------------------------------------------------------

  ChallengeVerdict? _timeFloor(ChallengeProposal p, ValidationContext ctx) {
    if (p.difficulty.timeLimitMs <= 0) return VerdictInvalid('time.nonPositive');
    if (p.difficulty.timeLimitMs > 8000) return VerdictInvalid('time.cap');
    final mech = p.mechanicContract;
    if (mech != null) {
      final speed = Difficulty.speedForLevel(ctx.level);
      final minMs = (mech.floorMs / speed).ceil();
      if (p.difficulty.timeLimitMs < minMs) return VerdictInvalid('time.floor');
    }
    if (p.difficulty.level < 1) return VerdictInvalid('time.level');
    return null;
  }

  // 6. Decoy honesty --------------------------------------------------------

  ChallengeVerdict? _decoyHonesty(ChallengeProposal p) {
    final correct = p.correctElement;
    if (correct == null) return null; // reported by check 8
    for (final e in p.elements) {
      if (e == correct) continue;
      if (!e.differsFrom(correct)) {
        return VerdictInvalid('decoy.identical'); // a decoy must be tempting
      }
    }
    return null;
  }

  // 7. Freshness ------------------------------------------------------------

  ChallengeVerdict? _freshness(ChallengeProposal p, ValidationContext ctx) {
    if (ctx.recentServed.isEmpty) return null;
    final sig = ServedChallengeStamp.ofProposal(p);
    for (final served in ctx.recentServed) {
      if (served.mechanic == sig.mechanic &&
          served.decoySignature == sig.decoySignature) {
        return VerdictInvalid('freshness.duplicate');
      }
    }
    return null;
  }

  // 8. Solution resolvability -----------------------------------------------

  ChallengeVerdict? _resolvability(ChallengeProposal p) {
    if (p.correctElement == null) return VerdictInvalid('solution.missing');
    if (p.difficulty.trickType == AiTrickType.swap && !p.correctAnswer.startsCorrect) {
      return VerdictInvalid('solution.swap'); // must start correct, swap away
    }
    return null;
  }

  // 9. Neutrality & tone ----------------------------------------------------

  ChallengeVerdict? _tone(ChallengeProposal p) {
    final text = [
      p.instruction,
      ...p.failLine.values,
      for (final e in p.elements) e.label,
    ].map((s) => s.toLowerCase()).join(' ');
    for (final f in {...kForbiddenTokens, ...kForbiddenTokensLocalized}) {
      if (text.contains(f)) return const VerdictFailureExit();
    }
    final words = text.split(_kNonWord);
    for (final t in {...kMetaAiTokens, ...kMetaAiTokensLocalized}) {
      if (words.contains(t)) return const VerdictInvalid('tone.metaAi');
    }
    return null;
  }

  // helpers ----------------------------------------------------------------

  static void _dimsDiffering(
      AiElement correct, AiElement e, Set<AiSenseDecoy> out) {
    if (e.color != correct.color) out.add(AiSenseDecoy.color);
    if (e.label != correct.label) out.add(AiSenseDecoy.label);
    if (e.shape != correct.shape) out.add(AiSenseDecoy.shape);
    if ((e.scale - correct.scale).abs() > 0.01) out.add(AiSenseDecoy.scale);
    if ((e.rotation - correct.rotation).abs() > 0.01) {
      out.add(AiSenseDecoy.rotation);
    }
    if ((e.opacity - correct.opacity).abs() > 0.01) out.add(AiSenseDecoy.opacity);
    if ((e.dx - correct.dx).abs() > 0.01 || (e.dy - correct.dy).abs() > 0.01) {
      out.add(AiSenseDecoy.position);
    }
  }
}