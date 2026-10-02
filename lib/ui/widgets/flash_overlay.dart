import 'package:flutter/material.dart';

import '../theme.dart';

/// Full-screen state feedback. This is the moment people screenshot.
class FlashOverlay extends StatelessWidget {
  const FlashOverlay({
    super.key,
    required this.correct,
    required this.message,
    this.note,
    this.aside,
    this.onSkip,
    this.skipHint,
  });

  final bool correct;
  final String message;
  final String? note;

  /// Optional extra beat under [message] (the single-player AI aside on the
  /// wrong flash). [message] stays the headline: it is the challenge's own
  /// fail line.
  final String? aside;

  /// When set, tapping anywhere on the overlay calls this instead of waiting
  /// out the flash — see `GameEngine.skipWrongFlash`.
  final VoidCallback? onSkip;
  final String? skipHint;

  @override
  Widget build(BuildContext context) {
    final color = correct ? Ays.correct : Ays.wrong;
    final textColor = correct ? Ays.bg : Ays.ink;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSkip,
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
                  style: Ays.title(72).copyWith(color: textColor),
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
              if (aside != null) ...[
                const SizedBox(height: 16),
                Text(
                  aside!,
                  textAlign: TextAlign.center,
                  style: Ays.label(
                    20,
                    color: textColor.withValues(alpha: 0.82),
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ],
              if (onSkip != null && skipHint != null) ...[
                const SizedBox(height: 20),
                Text(
                  skipHint!,
                  style: Ays.mono(11, color: textColor.withValues(alpha: 0.55)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
