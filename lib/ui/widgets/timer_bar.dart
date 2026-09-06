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
        child: Row(
          // The colored DecoratedBox below has no child of its own, so
          // without stretching it to the Row's full height it lays out at
          // zero height (loose cross-axis constraints) and is invisible —
          // this is why the bar never rendered on a real device.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: (left * 1000).round().clamp(1, 1000),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Expanded(
              flex: ((1 - left) * 1000).round().clamp(1, 1000),
              child: const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}
