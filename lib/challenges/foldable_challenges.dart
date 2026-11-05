/// UNFOLD YOUR BRAIN — the foldable challenges ([[Unfold Your Brain]]).
///
/// "The phone isn't your controller. The phone is the puzzle." Every
/// template here declares a [DeviceRequirement], so [ChallengeGenerator]
/// only serves it on a device that can judge it; on a conventional phone
/// they simply never appear. They read hardware exclusively through the
/// normalized [FoldableEvent] stream ([[Foldable Architecture]]), so the iOS
/// hinge and the dev simulator are indistinguishable here.
///
/// Safety ([[Unfold Your Brain]] → Safety): no challenge needs force, speed,
/// repetition or the hinge's extremes. Every round lasts at least
/// [FoldThresholds.minPhysicalRound], every threshold lives in
/// [FoldThresholds], and losing the hinge mid-round skips instead of failing.
library;

import '../core/challenge.dart';
import '../core/foldable.dart';
import 'base.dart';

/// What the round wanted the player to do physically. Read by the host
/// commentary to tell "folded instead of tapping" from the reverse.
enum ExpectedInteraction {
  partialFold,
  stayClosed,
  hingeAngle,
  displaySwitch,
  halfOpenThenTap,
}

/// Shared plumbing for hardware rounds.
abstract class FoldableChallenge extends BaseChallenge {
  FoldableChallenge(
    super.params, {
    required super.id,
    required Duration base,
    this.thresholds = FoldThresholds.standard,
  }) : super(
         tag: ChallengeTag.trick,
         duration: params.pace(
           base,
           floorMs: thresholds.minPhysicalRound.inMilliseconds,
         ),
       );

  final FoldThresholds thresholds;

  ExpectedInteraction get expected;

  /// The latest device state this round has seen.
  FoldableState hw = FoldableState.unknown;

  String? _quip;

  @override
  String? get successQuip => _quip;

  /// Shown on the next round's header ([Challenge.successQuip]).
  set quip(String? value) => _quip = value;

  @override
  void onDeviceEvent(FoldableEvent event, ChallengeHost host) {
    hw = event.current;
    if (event.kind == FoldableEventKind.hingeUnavailable) {
      // The hardware went away under the player: never their fault. Skip.
      _quip = params.tr('fold.common.skipped_quip');
      host.pass(note: params.tr('fold.common.skipped'));
      return;
    }
    onHardware(event, host);
    host.invalidate();
  }

  void onHardware(FoldableEvent event, ChallengeHost host);

  /// Reveals [hintKey] once half the round is gone: the hardware hint.
  void hintAtHalf(Duration elapsed, String hintKey) {
    if (hint == null && elapsed * 2 >= duration) hint = params.tr(hintKey);
  }
}

// ------------------------------------------------------------ 01 BEND OVER

/// Partially fold the phone. With a real angle, "partially" means
/// [FoldThresholds.bendTarget] ± [FoldThresholds.bendTolerance]; with only a
/// status, any `partiallyOpen` counts.
class BendOverChallenge extends FoldableChallenge {
  BendOverChallenge(super.params)
    : super(id: 'bend_over', base: const Duration(milliseconds: 6000)) {
    instruction = params.tr('fold.bend_over.instruction');
    layout = ChallengeLayout.none;
    _refresh();
  }

  @override
  ExpectedInteraction get expected => ExpectedInteraction.partialFold;

  bool get _inRange {
    if (hw.status != HingeStatus.partiallyOpen) return false;
    final angle = hw.angleDegrees;
    if (angle == null) return true;
    return (angle - thresholds.bendTarget).abs() <= thresholds.bendTolerance;
  }

  void _refresh() {
    final angle = hw.angleDegrees;
    device = DeviceVisual(
      kind: DeviceVisualKind.hinge,
      angleDegrees: angle,
      progress: angle == null
          ? (hw.status == HingeStatus.partiallyOpen ? 1 : 0)
          : (1 - (angle - thresholds.bendTarget).abs() / 90).clamp(0.0, 1.0),
    );
  }

  @override
  void onHardware(FoldableEvent event, ChallengeHost host) {
    _refresh();
    if (event.isPlayerAction && _inRange) {
      quip = params.tr('fold.bend_over.quip');
      host.pass();
    }
  }

  @override
  void onTick(Duration elapsed, ChallengeHost host) =>
      hintAtHalf(elapsed, 'fold.bend_over.hint');

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down) return;
    host.fail(reason: params.tr('fold.bend_over.tap'));
  }

  @override
  void onTimeout(ChallengeHost host) =>
      host.fail(reason: params.tr('fold.bend_over.fail'));
}

// ---------------------------------------------------------- 02 DON'T OPEN IT

/// Starts closed, a huge OPEN button begs to be pressed. Survive the timer
/// without opening the phone or touching the button.
class DontOpenChallenge extends FoldableChallenge {
  DontOpenChallenge(super.params)
    : super(id: 'dont_open', base: const Duration(milliseconds: 5000)) {
    instruction = params.tr('fold.dont_open.instruction');
    layout = ChallengeLayout.single;
    targets = [
      TargetSpec(
        id: 'open',
        label: params.tr('fold.dont_open.button'),
        color: GameColor.red,
        scale: 1.25,
      ),
    ];
  }

  @override
  ExpectedInteraction get expected => ExpectedInteraction.stayClosed;

  @override
  void onHardware(FoldableEvent event, ChallengeHost host) {
    final angle = hw.angleDegrees;
    final opened =
        event.kind == FoldableEventKind.deviceOpened ||
        (event.isPlayerAction &&
            angle != null &&
            angle > thresholds.openedAbove);
    if (opened) host.fail(reason: params.tr('fold.dont_open.fail'));
  }

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down || tap.isBackground) return;
    host.fail(reason: params.tr('fold.dont_open.fail'));
  }

  @override
  void onTimeout(ChallengeHost host) {
    quip = params.tr('fold.dont_open.quip');
    host.pass();
  }
}

// -------------------------------------------------------- 03 CRACK THE CODE

/// A safe whose combination is a hinge position. With a real angle the
/// target is a random angle (± [FoldThresholds.safeTolerance]); with only a
/// status it is the *other* open status. Either way it must be held for
/// [FoldThresholds.safeHold], so sweeping past it doesn't count.
class CrackTheCodeChallenge extends FoldableChallenge {
  CrackTheCodeChallenge(super.params)
    : super(id: 'crack_the_code', base: const Duration(milliseconds: 9000)) {
    instruction = params.tr('fold.crack_the_code.instruction');
    layout = ChallengeLayout.none;
    _visual();
  }

  @override
  ExpectedInteraction get expected => ExpectedInteraction.hingeAngle;

  /// Set on the first device event. Null until then.
  double? targetAngle;
  HingeStatus? targetStatus;
  Duration? _holdSince;
  Duration _now = Duration.zero;
  int _pulse = 0;
  int _band = 0;
  bool _solved = false;

  bool get usesAngle => targetAngle != null;

  void _pickTarget() {
    final angle = hw.angleDegrees;
    if (angle != null) {
      final steps = ((thresholds.maxSafeAngle - thresholds.minSafeAngle) / 10)
          .floor();
      final candidates = [
        for (var i = 0; i <= steps; i++) thresholds.minSafeAngle + i * 10,
      ].where((a) => (a - angle).abs() > thresholds.safeTolerance * 2).toList();
      targetAngle = candidates.isEmpty
          ? thresholds.bendTarget
          : params.pick(candidates);
    } else {
      targetStatus = hw.status == HingeStatus.partiallyOpen
          ? HingeStatus.fullyOpen
          : HingeStatus.partiallyOpen;
    }
  }

  double get _closeness {
    final t = targetAngle;
    final a = hw.angleDegrees;
    if (t != null && a != null) return (1 - (a - t).abs() / 90).clamp(0.0, 1.0);
    return hw.status == targetStatus ? 1 : 0.25;
  }

  bool get _onTarget {
    final t = targetAngle;
    final a = hw.angleDegrees;
    if (t != null) {
      return a != null && (a - t).abs() <= thresholds.safeTolerance;
    }
    return hw.status == targetStatus;
  }

  void _visual() {
    device = DeviceVisual(
      kind: DeviceVisualKind.safe,
      progress: targetAngle == null && targetStatus == null ? 0 : _closeness,
      solved: _solved,
      angleDegrees: hw.angleDegrees,
      pulse: _pulse,
    );
  }

  @override
  void onHardware(FoldableEvent event, ChallengeHost host) {
    if (targetAngle == null && targetStatus == null) _pickTarget();
    // A light tick each time the player gets meaningfully warmer.
    final band = (_closeness * 5).floor();
    if (event.isPlayerAction && band > _band) _pulse++;
    _band = band;
    if (_onTarget) {
      _holdSince ??= _now;
    } else {
      _holdSince = null;
    }
    _visual();
  }

  @override
  void onTick(Duration elapsed, ChallengeHost host) {
    _now = elapsed;
    hintAtHalf(elapsed, 'fold.crack_the_code.hint');
    final since = _holdSince;
    final hold = usesAngle ? thresholds.safeHold : thresholds.safeHold * 1.6;
    if (!_solved && since != null && elapsed - since >= hold) {
      _solved = true;
      _pulse++;
      _visual();
      quip = params.tr('fold.crack_the_code.quip');
      host.pass();
    }
  }

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down) return;
    host.fail(reason: params.tr('fold.crack_the_code.tap'));
  }

  @override
  void onTimeout(ChallengeHost host) =>
      host.fail(reason: params.tr('fold.crack_the_code.fail'));
}

// --------------------------------------------------------- 04 THE OTHER SIDE

/// A code with one digit missing. The digit is only shown after a display
/// configuration change (cover ↔ inner, or the simulator's toggle). Tapping
/// before looking is a guess, and guessing fails even when lucky.
class OtherSideChallenge extends FoldableChallenge {
  OtherSideChallenge(super.params)
    : super(id: 'other_side', base: const Duration(milliseconds: 9000)) {
    instruction = params.tr('fold.other_side.instruction');
    layout = ChallengeLayout.row;
    final rng = params.rng;
    final first = 1 + rng.nextInt(9);
    final last = rng.nextInt(10);
    final digits = params
        .shuffled([for (var d = 0; d < 10; d++) d])
        .take(3)
        .toList();
    missing = digits.first;
    final options = params.shuffled(digits);
    targets = [
      for (final d in options)
        TargetSpec(id: 'd$d', label: '$first$d$last', color: GameColor.slate),
    ];
    masked = '$first ? $last';
    _visual();
  }

  @override
  ExpectedInteraction get expected => ExpectedInteraction.displaySwitch;

  late final int missing;
  late final String masked;
  bool revealed = false;

  /// How many display switches happened — the host jokes about flapping.
  int switches = 0;

  void _visual() {
    device = DeviceVisual(
      kind: DeviceVisualKind.otherSide,
      revealed: revealed,
      label: revealed ? '$missing' : masked,
      progress: revealed ? 1 : 0,
    );
  }

  @override
  void onHardware(FoldableEvent event, ChallengeHost host) {
    if (event.kind != FoldableEventKind.displayConfigurationChanged) return;
    switches++;
    revealed = true; // Survives every further switch: state is never lost.
    _visual();
  }

  @override
  void onTick(Duration elapsed, ChallengeHost host) =>
      hintAtHalf(elapsed, 'fold.other_side.hint');

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down || tap.isBackground) return;
    if (targetById(tap.targetId) == null) return;
    if (!revealed) {
      host.fail(reason: params.tr('fold.other_side.guess'));
    } else if (tap.targetId == 'd$missing') {
      quip = params.tr('fold.other_side.quip');
      host.pass();
    } else {
      host.fail(reason: params.tr('fold.other_side.wrong'));
    }
  }

  @override
  void onTimeout(ChallengeHost host) =>
      host.fail(reason: params.tr('fold.other_side.fail'));
}

// --------------------------------------------------------- 05 OPEN YOUR MIND

/// Three shapes. Fully open, the "mind" names a decoy shape; half open it
/// names the real one. Pass = tap the real shape *while half open*.
/// "Open your mind" makes everyone open the phone all the way. Too open.
class OpenYourMindChallenge extends FoldableChallenge {
  OpenYourMindChallenge(super.params)
    : super(id: 'open_your_mind', base: const Duration(milliseconds: 9000)) {
    instruction = params.tr('fold.open_your_mind.instruction');
    layout = ChallengeLayout.row;
    final shapes = params.shuffled(_shapes);
    answer = shapes[0];
    decoy = shapes[1];
    targets = [
      for (final s in params.shuffled(_shapes))
        TargetSpec(id: s.name, shape: s, color: GameColor.purple, label: ''),
    ];
    _visual();
  }

  static const _shapes = [
    TargetShape.triangle,
    TargetShape.circle,
    TargetShape.diamond,
  ];

  @override
  ExpectedInteraction get expected => ExpectedInteraction.halfOpenThenTap;

  late final TargetShape answer;
  late final TargetShape decoy;

  bool get _halfOpen => hw.status == HingeStatus.partiallyOpen;

  String _say(TargetShape s) => params.tr('fold.open_your_mind.reveal', {
    'shape': params.tr('fold.shape.${s.name}'),
  });

  void _visual() {
    final status = hw.status;
    device = DeviceVisual(
      kind: DeviceVisualKind.mind,
      revealed: _halfOpen,
      angleDegrees: hw.angleDegrees,
      progress: switch (status) {
        HingeStatus.partiallyOpen => 1,
        HingeStatus.fullyOpen => 0.4,
        _ => 0,
      },
      label: switch (status) {
        HingeStatus.partiallyOpen => _say(answer),
        HingeStatus.fullyOpen => _say(decoy),
        _ => '…',
      },
    );
  }

  @override
  void onHardware(FoldableEvent event, ChallengeHost host) => _visual();

  @override
  void onTick(Duration elapsed, ChallengeHost host) =>
      hintAtHalf(elapsed, 'fold.open_your_mind.hint');

  @override
  void onTap(TapInfo tap, ChallengeHost host) {
    if (tap.kind != TapKind.down || tap.isBackground) return;
    if (targetById(tap.targetId) == null) return;
    if (tap.targetId != answer.name) {
      host.fail(reason: params.tr('fold.open_your_mind.wrong'));
    } else if (!_halfOpen) {
      host.fail(reason: params.tr('fold.open_your_mind.too_open'));
    } else {
      quip = params.tr('fold.open_your_mind.quip');
      host.pass();
    }
  }

  @override
  void onTimeout(ChallengeHost host) =>
      host.fail(reason: params.tr('fold.open_your_mind.fail'));
}

// --------------------------------------------------------------- registry

const _fold = {DeviceCapability.foldState};
const _open = {HingeStatus.partiallyOpen, HingeStatus.fullyOpen};

/// The foldable templates. Kept out of `kChallengeTemplates` on purpose:
/// multiplayer and iMessage rebuild rounds from that list on every device,
/// and a hinge round can't be judged on a phone without one
/// ([[Decision Log]]). The solo game screen appends these.
const kFoldableChallengeTemplates = <ChallengeTemplate>[
  ChallengeTemplate(
    id: 'bend_over',
    tag: ChallengeTag.trick,
    build: BendOverChallenge.new,
    minLevel: 4,
    weight: 0.7,
    requires: DeviceRequirement(
      capabilities: _fold,
      initialStatus: {HingeStatus.closed, HingeStatus.fullyOpen},
    ),
  ),
  ChallengeTemplate(
    id: 'dont_open',
    tag: ChallengeTag.patience,
    build: DontOpenChallenge.new,
    minLevel: 4,
    weight: 0.7,
    requires: DeviceRequirement(
      capabilities: _fold,
      initialStatus: {HingeStatus.closed},
    ),
  ),
  ChallengeTemplate(
    id: 'crack_the_code',
    tag: ChallengeTag.trick,
    build: CrackTheCodeChallenge.new,
    minLevel: 7,
    weight: 0.6,
    requires: DeviceRequirement(capabilities: _fold, initialStatus: _open),
  ),
  ChallengeTemplate(
    id: 'other_side',
    tag: ChallengeTag.trick,
    build: OtherSideChallenge.new,
    minLevel: 7,
    weight: 0.6,
    requires: DeviceRequirement(
      capabilities: {DeviceCapability.displayConfiguration},
    ),
  ),
  ChallengeTemplate(
    id: 'open_your_mind',
    tag: ChallengeTag.trick,
    build: OpenYourMindChallenge.new,
    minLevel: 8,
    weight: 0.6,
    requires: DeviceRequirement(capabilities: _fold, initialStatus: _open),
  ),
];

/// Every solo template for this device: classic + foldable. The generator
/// filters the foldable ones out wherever they can't be judged.
List<ChallengeTemplate> soloTemplates(List<ChallengeTemplate> classic) => [
  ...classic,
  ...kFoldableChallengeTemplates,
];
