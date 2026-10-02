import 'package:flutter/material.dart';

import '../theme.dart';

/// Depleting bar. Turns yellow, then red. No numbers: numbers slow people down.
class TimerBar extends StatelessWidget {
  const TimerBar({super.key, required this.progress, this.visible = true});

  /// 0 = just started, 1 = out of time.
  final double progress;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final left = (1 - progress).clamp(0.0, 1.0);
    final color = left > 0.5
        ? Ays.ink
        : left > 0.22
            ? Ays.warning
            : Ays.wrong;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 140),
      child: SizedBox(
        height: 8,
        // An explicit pixel width via LayoutBuilder, not a Row/Expanded flex
        // ratio: a flex-based fill (a childless DecoratedBox sized only by
        // Expanded) depends on cross-axis constraints propagating a certain
        // way and turned out to lay out at zero height in practice — see
        // docs/Meta/Decision Log.md. A `Container` given both dimensions
        // directly can't fall into that trap on any rendering backend.
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: constraints.maxWidth * left,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
