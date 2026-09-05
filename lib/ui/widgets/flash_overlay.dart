import 'package:flutter/material.dart';

import '../theme.dart';

/// Full-screen state feedback. This is the moment people screenshot.
class FlashOverlay extends StatelessWidget {
  const FlashOverlay({
    super.key,
    required this.correct,
    required this.message,
    this.note,
  });

  final bool correct;
  final String message;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final color = correct ? Ays.correct : Ays.wrong;
    return IgnorePointer(
      ignoring: false,
      child: Container(
        color: color,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Ays.title(72).copyWith(
                    color: correct ? Ays.bg : Ays.ink,
                  ),
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: 12),
                Text(
                  note!,
                  style: Ays.label(
                    26,
                    color: correct ? Ays.bg.withValues(alpha: 0.7) : Ays.ink,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
