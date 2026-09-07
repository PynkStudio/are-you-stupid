/// A challenge produced by a [ChallengeProvider], wrapped with provenance.
///
/// Phase 1 carries the built [challenge] plus [source]. The model-facing
/// fields (mechanic vocabulary, elements, correctAnswer, failLine) join with
/// Phase 2 — [[AI Challenge Generation]] describes the full portable shape.
library;

import '../core/challenge.dart';

class GeneratedChallenge {
  GeneratedChallenge({
    required this.challenge,
    required this.source,
    String? id,
    int? seed,
  })  : id = id ?? challenge.id,
        seed = seed ?? 0;

  /// The built, playable challenge.
  final Challenge challenge;

  /// Where this challenge came from: `scripted` today, `ai` once the model
  /// path lands. The engine never branches on it — telemetry and debug
  /// captures only ([[Privacy and Offline]]).
  final String source;

  /// Stable id. AI proposals are prefixed `ai.` ([[AI Challenge Generation]]).
  final String id;

  /// Determinism seed for multiplayer rounds ([[Multiplayer AI Director]]).
  /// 0 = the provider's own randomness (solo).
  final int seed;
}