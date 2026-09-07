/// The Dart side of the Apple Intelligence bridge ([[Foundation Models
/// Integration]] → MethodChannel contract).
///
/// One service, one channel, zero engine coupling:
///
/// - `lib/core/` and `lib/challenges/` never import this file — the engine
///   talks to [ChallengeProvider]s, and the AI provider (Phase 5) is the only
///   consumer of this service.
/// - Every call here is **request → JSON result**; Swift never streams the
///   model and Dart never sees the session. Results are *proposals* until the
///   [[AI Challenge Validator]] passes them.
/// - Real inference is exercised through [AppleAiMethodChannel]; tests always
///   inject a [MockAppleAIService].
///
/// This file may import `flutter/services.dart` (it is a bridge) but no
/// widgets and nothing from `core/`.
library;

import 'package:flutter/services.dart';

import '../i18n/app_locale.dart';

/// Transport-level bridge name, kept in lockstep with the Swift side
/// ([[Testing and Evaluation]] → protocol fixtures).
const String kAppleIntelligenceChannel = 'ays/apple_intelligence';

/// Availability snapshot the UI and [[Feature Flags]] read (→ AI Experience
/// Modes). Mirror of the Swift ladder ([[Foundation Models Integration]] →
/// availability).
class AppleAiAvailability {
  const AppleAiAvailability(this.state, {this.reason});

  /// `available` or `unavailable`.
  final String state;

  /// Swift `UnavailableReason` when [state] is `unavailable`: device not
  /// eligible / Apple Intelligence off / model not ready / bridge missing.
  final String? reason;

  bool get isAvailable => state == 'available';

  static AppleAiAvailability fromJson(Map<Object?, Object?> json) =>
      AppleAiAvailability(
        (json['state'] as String?) ?? 'unavailable',
        reason: json['reason'] as String?,
      );
}

/// A GenerationError mapped to the wire ([[Foundation Models Integration]] →
/// errors): `guardrailViolation`, `refusal`, `rateLimited`,
/// `concurrentRequests`, `exceededContextWindowSize`, `assetsUnavailable`,
/// `unsupportedLanguageOrLocale`, `decodingFailure`, `toolCallError`,
/// `unavailable`.
class AppleAiError {
  const AppleAiError(this.code, {this.retryable = false, this.message});

  final String code;

  /// Whether regenerating the same unit may succeed (transient/environmental
  /// errors). Content-level failures are never retryable.
  final bool retryable;

  final String? message;

  static AppleAiError? fromJson(Map<Object?, Object?> json) {
    final raw = json['error'];
    if (raw is! Map) return null;
    final code = (raw['code'] as String?) ?? 'unknown';
    final retryable = (raw['retryable'] as bool?) ?? false;
    final message = raw['message'] as String?;
    return AppleAiError(code, retryable: retryable, message: message);
  }
}

/// Result of a proposal-generating call (`requestChallenge`,
/// `requestFinalRound`, `requestMultiplayerHost`).
class AppleAiProposalResult {
  const AppleAiProposalResult.ok(this.proposal, {this.unitId})
      : ok = true,
        error = null;

  const AppleAiProposalResult.fail(this.error, {this.unitId})
      : ok = false,
        proposal = null;

  final bool ok;
  final String? unitId;

  /// Raw proposal JSON. Only present when [ok]. The Dart [[AI Challenge
  /// Validator]] runs on the decoded [ChallengeProposal] before anything
  /// reaches the player.
  final Map<String, dynamic>? proposal;

  final AppleAiError? error;
}

/// Result of a text call (`requestCommentary`).
class AppleAiTextResult {
  const AppleAiTextResult.ok(this.text, {this.unitId})
      : ok = true,
        error = null;

  const AppleAiTextResult.fail(this.error, {this.unitId})
      : ok = false,
        text = null;

  final bool ok;
  final String? unitId;
  final String? text;
  final AppleAiError? error;
}

/// The payload shape the pre-generation edges use today (Phase 2 ships the
/// channel shape; the provider that consumes `requestChallenge` lands in
/// Phase 5). All map values are plain JSON.
typedef AppleAiPayload = Map<String, Object?>;

/// The native AI surface. Everything is async and non-blocking by contract;
/// providers compose it through a cache, never synchronously.
abstract class AppleAIService {
  /// Current availability; never throws — a missing bridge maps to
  /// `unavailable(bridgeUnavailable)`.
  Future<AppleAiAvailability> available();

  /// One prefetch unit → one constrained challenge proposal.
  Future<AppleAiProposalResult> requestChallenge({
    required String unitId,
    required AppLocale locale,
    AppleAiPayload profile = const {},
  });

  /// Commentary/roast for an event (`failure`, `streak`, `edit`);
  /// `context` carries the per-kind data.
  Future<AppleAiTextResult> requestCommentary({
    required String unitId,
    required AppLocale locale,
    required String kind,
    AppleAiPayload context = const {},
  });

  /// The game-ending question built on this player's profile.
  Future<AppleAiProposalResult> requestFinalRound({
    required String unitId,
    required AppLocale locale,
    AppleAiPayload profile = const {},
  });

  /// The host-side first-round question for a party ([[Multiplayer AI
  /// Director]]); deterministic via `seed`.
  Future<AppleAiProposalResult> requestMultiplayerHost({
    required String unitId,
    required AppLocale locale,
    AppleAiPayload profile = const {},
  });

  /// Best-effort cancellation of one unit (mode/flip changes).
  Future<bool> cancelUnit(String unitId);

  /// On-device quality feedback; nothing depends on it ([[Privacy and
  /// Offline]]).
  Future<bool> feedback({
    required String sentiment,
    String? issue,
    String? excerpt,
  });
}

/// Real transport over `ays/apple_intelligence`.
class AppleAiMethodChannel implements AppleAIService {
  AppleAiMethodChannel({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(kAppleIntelligenceChannel);

  final MethodChannel _channel;

  @override
  Future<AppleAiAvailability> available() async {
    final raw = await _invoke('available', const {});
    final json = _asMap(raw);
    return json == null
        ? const AppleAiAvailability('unavailable', reason: 'bridgeUnavailable')
        : AppleAiAvailability.fromJson(json);
  }

  @override
  Future<AppleAiProposalResult> requestChallenge({
    required String unitId,
    required AppLocale locale,
    AppleAiPayload profile = const {},
  }) async {
    final raw = await _invoke('requestChallenge', {
      'unitId': unitId,
      'locale': locale.code,
      'profile': profile,
    });
    return _decodeProposalResult(_asMap(raw), unitId);
  }

  @override
  Future<AppleAiTextResult> requestCommentary({
    required String unitId,
    required AppLocale locale,
    required String kind,
    AppleAiPayload context = const {},
  }) async {
    final raw = await _invoke('requestCommentary', {
      'unitId': unitId,
      'locale': locale.code,
      'kind': kind,
      'context': context,
    });
    return _decodeTextResult(_asMap(raw), unitId);
  }

  @override
  Future<AppleAiProposalResult> requestFinalRound({
    required String unitId,
    required AppLocale locale,
    AppleAiPayload profile = const {},
  }) async {
    final raw = await _invoke('requestFinalRound', {
      'unitId': unitId,
      'locale': locale.code,
      'profile': profile,
    });
    return _decodeProposalResult(_asMap(raw), unitId);
  }

  @override
  Future<AppleAiProposalResult> requestMultiplayerHost({
    required String unitId,
    required AppLocale locale,
    AppleAiPayload profile = const {},
  }) async {
    final raw = await _invoke('requestMultiplayerHost', {
      'unitId': unitId,
      'locale': locale.code,
      'profile': profile,
    });
    return _decodeProposalResult(_asMap(raw), unitId);
  }

  @override
  Future<bool> cancelUnit(String unitId) async {
    final raw = await _invoke('cancelUnit', {'unitId': unitId});
    return raw is bool && raw;
  }

  @override
  Future<bool> feedback({
    required String sentiment,
    String? issue,
    String? excerpt,
  }) async {
    final raw = await _invoke('feedback', {
      'sentiment': sentiment,
      'issue': ?issue,
      'excerpt': ?excerpt,
    });
    return raw is bool && raw;
  }

  Future<Object?> _invoke(String method, AppleAiPayload args) async {
    try {
      return await _channel.invokeMethod<Object?>(method, args);
    } on MissingPluginException {
      // No native bridge (tests, simulators, dev). The seamless fallback is a
      // contract: callers treat this as an `unavailable` result, never a crash.
      return null;
    } on PlatformException catch (e) {
      return <Object?, Object?>{
        'ok': false,
        'error': <Object?, Object?>{
          'code': 'unavailable',
          'retryable': false,
          'message': e.message,
        },
      };
    }
  }

  static Map<Object?, Object?>? _asMap(Object? raw) =>
      raw is Map ? Map<Object?, Object?>.from(raw) : null;

  AppleAiProposalResult _decodeProposalResult(
      Map<Object?, Object?>? json, String unitId) {
    if (json == null) {
      return AppleAiProposalResult.fail(const AppleAiError('unavailable'),
          unitId: unitId);
    }
    final ok = (json['ok'] as bool?) ?? false;
    if (!ok) {
      return AppleAiProposalResult.fail(
          AppleAiError.fromJson(json) ?? const AppleAiError('unknown'),
          unitId: unitId);
    }
    final proposal = json['proposal'];
    if (proposal is! Map) {
      return AppleAiProposalResult.fail(
          const AppleAiError('decodingFailure', retryable: false),
          unitId: unitId);
    }
    return AppleAiProposalResult.ok(
      Map<String, dynamic>.from(proposal),
      unitId: unitId,
    );
  }

  AppleAiTextResult _decodeTextResult(Map<Object?, Object?>? json, String unitId) {
    if (json == null) {
      return AppleAiTextResult.fail(const AppleAiError('unavailable'),
          unitId: unitId);
    }
    final ok = (json['ok'] as bool?) ?? false;
    if (!ok) {
      return AppleAiTextResult.fail(
          AppleAiError.fromJson(json) ?? const AppleAiError('unknown'),
          unitId: unitId);
    }
    final text = json['text'];
    if (text is! String || text.isEmpty) {
      return AppleAiTextResult.fail(
          const AppleAiError('decodingFailure', retryable: false),
          unitId: unitId);
    }
    return AppleAiTextResult.ok(text, unitId: unitId);
  }
}

/// The mock every test that touches the bridge uses ([[Testing and
/// Evaluation]] → the native layer is never exercised as a unit here).
///
/// Scriptable: set the next result before the call, then assert on the call
/// log. Recording the payload lets tests pin the wire contract on the Dart
/// side.
class MockAppleAIService implements AppleAIService {
  AppleAiAvailability availability = const AppleAiAvailability('available');

  AppleAiProposalResult? nextChallengeResult;
  AppleAiProposalResult? nextFinalRoundResult;
  AppleAiProposalResult? nextMultiplayerHostResult;
  AppleAiTextResult? nextCommentaryResult;

  bool cancelUnitResult = true;
  bool feedbackResult = true;

  final AppleAiProposalResult _defaultFail = const AppleAiProposalResult.fail(
      AppleAiError('unavailable'));

  /// method → list of payloads received (each a per-call copy, in order).
  final Map<String, List<AppleAiPayload>> calls = {};

  void _log(String method, AppleAiPayload payload) {
    calls.putIfAbsent(method, () => []).add(Map<String, Object?>.of(payload));
  }

  @override
  Future<AppleAiAvailability> available() async => availability;

  @override
  Future<AppleAiProposalResult> requestChallenge({
    required String unitId,
    required AppLocale locale,
    AppleAiPayload profile = const {},
  }) async {
    _log('requestChallenge',
        {'unitId': unitId, 'locale': locale.code, 'profile': profile});
    return nextChallengeResult ?? _defaultFail;
  }

  @override
  Future<AppleAiTextResult> requestCommentary({
    required String unitId,
    required AppLocale locale,
    required String kind,
    AppleAiPayload context = const {},
  }) async {
    _log('requestCommentary',
        {'unitId': unitId, 'locale': locale.code, 'kind': kind, 'context': context});
    return nextCommentaryResult ??
        const AppleAiTextResult.fail(AppleAiError('unavailable'));
  }

  @override
  Future<AppleAiProposalResult> requestFinalRound({
    required String unitId,
    required AppLocale locale,
    AppleAiPayload profile = const {},
  }) async {
    _log('requestFinalRound',
        {'unitId': unitId, 'locale': locale.code, 'profile': profile});
    return nextFinalRoundResult ?? _defaultFail;
  }

  @override
  Future<AppleAiProposalResult> requestMultiplayerHost({
    required String unitId,
    required AppLocale locale,
    AppleAiPayload profile = const {},
  }) async {
    _log('requestMultiplayerHost',
        {'unitId': unitId, 'locale': locale.code, 'profile': profile});
    return nextMultiplayerHostResult ?? _defaultFail;
  }

  @override
  Future<bool> cancelUnit(String unitId) async {
    _log('cancelUnit', {'unitId': unitId});
    return cancelUnitResult;
  }

  @override
  Future<bool> feedback({
    required String sentiment,
    String? issue,
    String? excerpt,
  }) async {
    _log('feedback', {
      'sentiment': sentiment,
      'issue': ?issue,
      'excerpt': ?excerpt,
    });
    return feedbackResult;
  }
}