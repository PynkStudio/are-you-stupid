import '../core/challenge.dart';
import '../i18n/app_locale.dart';
import '../i18n/strings.dart';

/// Mutable scaffolding shared by every challenge.
///
/// Subclasses mutate [instruction] / [targets] / etc. freely and call
/// `host.invalidate()` when they change something outside of a tap.
abstract class BaseChallenge extends Challenge {
  BaseChallenge(
    super.params, {
    required this.id,
    required this.tag,
    required this.duration,
  });

  @override
  final String id;

  @override
  final ChallengeTag tag;

  @override
  final Duration duration;

  String instruction = '';
  String? hint;
  String? bigCenterText;
  ChallengeLayout layout = ChallengeLayout.grid2x2;
  List<TargetSpec> targets = const [];
  bool blackout = false;
  bool showTimer = true;
  double pressure = 0;
  String? tapCounter;
  String? note;

  @override
  String? get successNote => note;

  @override
  ChallengeView get view => ChallengeView(
        instruction: instruction,
        layout: layout,
        targets: targets,
        hint: hint,
        bigCenterText: bigCenterText,
        blackout: blackout,
        showTimer: showTimer,
        pressure: pressure,
        tapCounter: tapCounter,
      );

  /// The current target with [targetId], or null when the tap hit a button
  /// that was just swapped out (e.g. a show→ask phase change landing in the
  /// same frame as the tap) — callers ignore such a stale tap.
  TargetSpec? targetById(String? targetId) {
    for (final t in targets) {
      if (t.id == targetId) return t;
    }
    return null;
  }

  /// Replaces the target with [id] using [update].
  void mutateTarget(String targetId, TargetSpec Function(TargetSpec) update) {
    targets = [
      for (final t in targets) if (t.id == targetId) update(t) else t,
    ];
  }
}

/// "Tap the right thing" — the most common shape of challenge.
class TapTargetChallenge extends BaseChallenge {
  TapTargetChallenge(
    super.params, {
    required super.id,
    required super.tag,
    required super.duration,
    required String instruction,
    required List<TargetSpec> targets,
    required this.correctIds,
    ChallengeLayout layout = ChallengeLayout.grid2x2,
    String? hint,
    this.backgroundFails = false,
    this.wrongReason,
    this.lateReason,
  }) {
    this.instruction = instruction;
    this.targets = targets;
    this.layout = layout;
    this.hint = hint;
  }

  final Set<String> correctIds;
  final bool backgroundFails;
  final String? wrongReason;
  final String? lateReason;

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down) return;
    if (tap.isBackground) {
      if (backgroundFails) {
        host.fail(reason: params.tr('common.you_missed_button'));
      }
      return;
    }
    if (correctIds.contains(tap.targetId)) {
      host.pass();
    } else {
      host.fail(reason: wrongReason);
    }
  }

  @override
  void onTimeout(ChallengeHost host) =>
      host.fail(reason: lateReason ?? params.tr('common.too_slow'));
}

/// "Do nothing and survive" — passes when the timer runs out.
class PatienceChallenge extends BaseChallenge {
  PatienceChallenge(
    super.params, {
    required super.id,
    required super.tag,
    required super.duration,
    required String instruction,
    this.tapReason,
  }) {
    this.instruction = instruction;
    layout = ChallengeLayout.none;
  }

  final String? tapReason;

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.kind == TapKind.up) return;
    host.fail(reason: tapReason ?? params.tr('common.one_job'));
  }

  @override
  void onTimeout(ChallengeHost host) => host.pass();
}

// --------------------------------------------------------------- tiny helpers

/// Four (or N) buttons whose label matches their own color.
List<TargetSpec> honestColorTargets(List<GameColor> colors, AppLocale locale) => [
      for (var i = 0; i < colors.length; i++)
        TargetSpec(
          id: 'c$i',
          label: Strings.t(locale, 'color.${colors[i].name}'),
          color: colors[i],
        ),
    ];

/// Buttons where label and paint are decoupled.
List<TargetSpec> mixedColorTargets(
  List<GameColor> paints,
  List<GameColor> words,
  AppLocale locale,
) =>
    [
      for (var i = 0; i < paints.length; i++)
        TargetSpec(
          id: 'c$i',
          label: Strings.t(locale, 'color.${words[i].name}'),
          color: paints[i],
        ),
    ];

List<TargetSpec> numberTargets(List<int> numbers) => [
      for (var i = 0; i < numbers.length; i++)
        TargetSpec(
          id: 'n${numbers[i]}',
          label: '${numbers[i]}',
          color: GameColor.slate,
        ),
    ];

List<TargetSpec> wordTargets(List<String> words, {GameColor? color}) => [
      for (var i = 0; i < words.length; i++)
        TargetSpec(id: 'w$i', label: words[i], color: color ?? GameColor.slate),
    ];
