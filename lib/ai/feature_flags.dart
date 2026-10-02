/// AI feature flags — the reversibility contract every later AI phase reads
/// through ([[Feature Flags]], [[Quality Neutrality and Guardrails]] →
/// Mitigation & rollback).
///
/// This is the **data module** only (Phase B of the AI Director plan,
/// `docs/Meta/Decision Log.md`): local `SharedPreferences`-backed flags, no
/// Settings UI yet (that's a later phase — `AiFeatureFlags` is deliberately
/// usable standalone so Phases 4-8 don't need to wait on it or get
/// retrofitted later).
///
/// All flags live under `lib/ai/`'s own key namespace (`ayu.*`, matching
/// `lib/ai/telemetry.dart`'s `ayu.profile` — a different prefix from the
/// rest of the app's `ays.*` settings, an established precedent this file
/// follows rather than reinvents). No remote configuration, ever — every
/// value here is compiled-in defaults + a local on/off switch.
///
/// **Scope note:** the design doc describes flags as tri-state
/// (`enabled | disabled | unavailable`). This module only ever persists
/// `enabled`/`disabled` — `unavailable` is a *device capability* fact
/// (`AppleAiAvailability`, fetched async from the bridge), not something to
/// persist here. Whoever combines a flag with live availability (the
/// pre-generation cache, the commentary provider) computes the "unavailable"
/// overlay itself; this file stays synchronous and side-effect-free to read,
/// exactly as [[Feature Flags]] requires ("reads are snapshots per event,
/// not cached decisions").
///
/// This file is PURE DART except for the `shared_preferences` package
/// itself (already used the same way by every other settings/persistence
/// class in this codebase).
library;

import 'package:shared_preferences/shared_preferences.dart';

/// The three-position control Settings will eventually show
/// ([[Feature Flags]] → AI Experience Modes). A label over the flags below,
/// not a fourth independent flag.
enum AiExperienceMode {
  /// Full experience — AI challenges + commentary. Every flag below
  /// `enabled` (adaptive difficulty stays whatever it already was — see
  /// [AiFeatureFlags.aiAdaptiveDifficultyEnabled]'s own doc).
  genius,

  /// Only the AI that keeps the core intact: commentary stays, generation
  /// stays on but conservative. The flags are identical to [genius] — the
  /// difference is in *how* Phase 6 calls the model (temperature/sampling),
  /// not which flags are set.
  focused,

  /// Pure scripted, as the game ships without any AI work at all.
  classic;

  static AiExperienceMode fromName(String? name) => switch (name) {
        'genius' => AiExperienceMode.genius,
        'focused' => AiExperienceMode.focused,
        'classic' => AiExperienceMode.classic,
        _ => AiExperienceMode.genius,
      };
}

/// Local, reversible switches gating every AI use-case. See the mitigation
/// ladder in [[Quality Neutrality and Guardrails]]: unit failover (not this
/// file) → per-feature flag (this file) → mode (this file) → master (this
/// file) → identical to a pre-AI build.
class AiFeatureFlags {
  AiFeatureFlags(this._prefs);

  static const _kDynamicAI = 'ayu.dynamicAI.enabled';
  static const _kChallengeGeneration = 'ayu.dynamicAI.challengeGeneration';
  static const _kCommentary = 'ayu.dynamicAI.commentary';
  static const _kAdaptiveDifficulty = 'ayu.dynamicAI.adaptiveDifficulty';
  static const _kMultiplayerDirector = 'ayu.dynamicAI.multiplayerDirector';
  static const _kFailover = 'ayu.dynamicAI.failover';
  static const _kObservability = 'ayu.dynamicAI.observability';
  static const _kMode = 'ayu.dynamicAI.mode';

  final SharedPreferences _prefs;

  static Future<AiFeatureFlags> load() async =>
      AiFeatureFlags(await SharedPreferences.getInstance());

  /// The master switch. `false` means no AI code path runs at all — every
  /// other flag below reads as `false` regardless of its own persisted
  /// value, so flipping this one alone is a complete, instant rollback to a
  /// pre-AI build.
  bool get dynamicAIEnabled => _prefs.getBool(_kDynamicAI) ?? true;

  /// AI challenge generation vs. scripted-only ([[AI Challenge Generation]]).
  bool get aiChallengeGenerationEnabled =>
      dynamicAIEnabled && (_prefs.getBool(_kChallengeGeneration) ?? true);

  /// AI-written commentary vs. static-bank-only ([[AI Commentary]]).
  bool get aiCommentaryEnabled =>
      dynamicAIEnabled && (_prefs.getBool(_kCommentary) ?? true);

  /// Territory/tension re-weighting from [[Player Telemetry and Adaptive
  /// Difficulty]]. Defaults **off** — unlike every other flag, this one
  /// isn't part of the [AiExperienceMode] ladder (the doc's Genius row says
  /// "+ adaptive if it's ever enabled," a parenthetical carve-out, not a
  /// forced-on default) — [setMode] never touches it, so a player's own
  /// choice here survives a mode switch in either direction.
  bool get aiAdaptiveDifficultyEnabled =>
      dynamicAIEnabled && (_prefs.getBool(_kAdaptiveDifficulty) ?? false);

  /// The multiplayer AI Director Host election ([[Multiplayer AI Director]]).
  bool get aiMultiplayerDirectorEnabled =>
      dynamicAIEnabled && (_prefs.getBool(_kMultiplayerDirector) ?? true);

  /// Silent scripted fallback on a failed AI unit. When `false`, a failing
  /// unit is simply not served (gameplay still never blocks — this only
  /// changes whether the *slot* gets a scripted substitute or nothing).
  bool get aiFailoverEnabled =>
      dynamicAIEnabled && (_prefs.getBool(_kFailover) ?? true);

  /// Local-only QA counters ([[Privacy and Offline]] → Observability).
  /// Never leaves the device regardless of this flag; it only gates whether
  /// the counters are kept at all.
  bool get aiObservabilityEnabled =>
      dynamicAIEnabled && (_prefs.getBool(_kObservability) ?? true);

  /// The current [AiExperienceMode] label. Defaults to [AiExperienceMode.genius]
  /// — AI is opt-out, never opt-in ([[Quality Neutrality and Guardrails]]).
  AiExperienceMode get mode =>
      AiExperienceMode.fromName(_prefs.getString(_kMode));

  /// Applies one of the three experience modes, writing every flag [mode]
  /// controls in one call ([[Feature Flags]] → AI Experience Modes table).
  /// [aiAdaptiveDifficultyEnabled] is deliberately excluded — see its own
  /// doc comment. `classic` only ever flips the master switch: sub-flags
  /// are left as they were, so switching back to `genius`/`focused` later
  /// restores whatever posture the player had instead of resetting it.
  Future<void> setMode(AiExperienceMode mode) async {
    await _prefs.setString(_kMode, mode.name);
    switch (mode) {
      case AiExperienceMode.genius:
      case AiExperienceMode.focused:
        await _prefs.setBool(_kDynamicAI, true);
        await _prefs.setBool(_kChallengeGeneration, true);
        await _prefs.setBool(_kCommentary, true);
        await _prefs.setBool(_kMultiplayerDirector, true);
        await _prefs.setBool(_kFailover, true);
        await _prefs.setBool(_kObservability, true);
      case AiExperienceMode.classic:
        await _prefs.setBool(_kDynamicAI, false);
    }
  }

  Future<void> setDynamicAIEnabled(bool value) =>
      _prefs.setBool(_kDynamicAI, value);

  Future<void> setChallengeGenerationEnabled(bool value) =>
      _prefs.setBool(_kChallengeGeneration, value);

  Future<void> setCommentaryEnabled(bool value) =>
      _prefs.setBool(_kCommentary, value);

  Future<void> setAdaptiveDifficultyEnabled(bool value) =>
      _prefs.setBool(_kAdaptiveDifficulty, value);

  Future<void> setMultiplayerDirectorEnabled(bool value) =>
      _prefs.setBool(_kMultiplayerDirector, value);

  Future<void> setFailoverEnabled(bool value) =>
      _prefs.setBool(_kFailover, value);

  Future<void> setObservabilityEnabled(bool value) =>
      _prefs.setBool(_kObservability, value);
}
