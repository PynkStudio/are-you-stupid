import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/challenge.dart';
import '../theme.dart';
import 'target_button.dart';
import 'balanced_text.dart';

/// Lets the background listener know a target already handled this pointer.
///
/// Children receive pointer events before their ancestors, so a target can
/// simply flag the event and the background listener skips it.
class TapClaim {
  bool _down = false;
  bool _up = false;

  void claimDown() => _down = true;
  void claimUp() => _up = true;

  bool consumeDown() {
    final was = _down;
    _down = false;
    return was;
  }

  bool consumeUp() {
    final was = _up;
    _up = false;
    return was;
  }
}

/// Turns a [ChallengeView] into pixels. Knows nothing about game rules.
class ChallengeRenderer extends StatelessWidget {
  const ChallengeRenderer({
    super.key,
    required this.view,
    required this.claim,
    required this.onTarget,
  });

  final ChallengeView view;
  final TapClaim claim;

  /// (targetId, visual index, kind)
  final void Function(String id, int index, TapKind kind) onTarget;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InstructionBlock(view: view),
        Expanded(child: _PlayArea(view: view, claim: claim, onTarget: onTarget)),
      ],
    );
  }
}

class _InstructionBlock extends StatelessWidget {
  const _InstructionBlock({required this.view});

  final ChallengeView view;

  @override
  Widget build(BuildContext context) {
    final pressure = view.pressure;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: SizedBox(
        height: 132,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: 1 + pressure * 0.06,
              duration: const Duration(milliseconds: 120),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 96),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    view.instruction,
                    textAlign: TextAlign.center,
                    style: Ays.instruction(46),
                  ),
                ),
              ),
            ),
            if (view.hint != null) ...[
              const SizedBox(height: 10),
              Text(
                view.hint!,
                textAlign: TextAlign.center,
                style: Ays.label(18, color: Ays.inkDim),
              ),
            ],
            if (view.tapCounter != null) ...[
              const SizedBox(height: 10),
              Text(view.tapCounter!, style: Ays.mono(20, color: Ays.warning)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayArea extends StatelessWidget {
  const _PlayArea({
    required this.view,
    required this.claim,
    required this.onTarget,
  });

  final ChallengeView view;
  final TapClaim claim;
  final void Function(String id, int index, TapKind kind) onTarget;

  @override
  Widget build(BuildContext context) {
    if (view.blackout) {
      return const SizedBox.expand();
    }

    final big = view.bigCenterText;
    final grid = _buildTargets(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        children: [
          if (big != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: BalancedText(big, style: Ays.title(76), maxLines: 1),
            ),
          Expanded(child: grid),
        ],
      ),
    );
  }

  Widget _target(TargetSpec spec, int index, {bool dense = false}) {
    return TargetButton(
      spec: spec,
      dense: dense,
      onDown: () {
        claim.claimDown();
        onTarget(spec.id, index, TapKind.down);
      },
      onUp: () {
        claim.claimUp();
        onTarget(spec.id, index, TapKind.up);
      },
    );
  }

  Widget _buildTargets(BuildContext context) {
    final targets = view.targets;
    switch (view.layout) {
      case ChallengeLayout.none:
        return const SizedBox.expand();

      case ChallengeLayout.single:
        if (targets.isEmpty) return const SizedBox.expand();
        return LayoutBuilder(
          builder: (context, c) {
            final side = math.min(c.maxWidth, c.maxHeight) * 0.72;
            return Center(
              child: SizedBox(
                width: side,
                height: side,
                child: _target(targets.first, 0),
              ),
            );
          },
        );

      case ChallengeLayout.row:
        return Row(
          children: [
            for (var i = 0; i < targets.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              Expanded(child: _target(targets[i], i)),
            ],
          ],
        );

      case ChallengeLayout.grid2x2:
        return _grid(targets, 2);

      case ChallengeLayout.grid3:
        return _grid(targets, 3, dense: true);

      case ChallengeLayout.free:
        return Stack(
          children: [
            for (var i = 0; i < targets.length; i++)
              Align(
                alignment: Alignment(
                  targets[i].x * 2 - 1,
                  targets[i].y * 2 - 1,
                ),
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: _target(targets[i], i),
                ),
              ),
          ],
        );
    }
  }

  Widget _grid(List<TargetSpec> targets, int columns, {bool dense = false}) {
    final rows = (targets.length / columns).ceil();
    return Column(
      children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) const SizedBox(height: 14),
          Expanded(
            child: Row(
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: 14),
                  Expanded(
                    child: (r * columns + c) < targets.length
                        ? _target(
                            targets[r * columns + c],
                            r * columns + c,
                            dense: dense,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
