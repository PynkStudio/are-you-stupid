import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/challenge.dart';
import '../theme.dart';
import 'balanced_text.dart';

/// Draws a [DeviceVisual] — the hardware half of a foldable challenge
/// ([[Rendering Pipeline]] → Foldable visuals). Knows nothing about rules.
///
/// Everything is generated (no assets) and sized from the available box, so
/// it reads the same on a compact cover display and an unfolded inner one.
/// Honors reduce-motion: with animations disabled every transition is
/// instant and the hint loop stops.
class FoldableVisual extends StatefulWidget {
  const FoldableVisual({super.key, required this.visual});

  final DeviceVisual visual;

  @override
  State<FoldableVisual> createState() => _FoldableVisualState();
}

class _FoldableVisualState extends State<FoldableVisual>
    with SingleTickerProviderStateMixin {
  /// Drives the "breathing" interaction hint.
  late final AnimationController _hint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _hint.stop();
    } else if (!_hint.isAnimating) {
      _hint.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.visual;
    final still = MediaQuery.disableAnimationsOf(context);
    final quick = still ? Duration.zero : const Duration(milliseconds: 220);
    return LayoutBuilder(
      builder: (context, c) {
        final side = math.min(c.maxWidth, c.maxHeight);
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: switch (v.kind) {
              DeviceVisualKind.hinge => AnimatedBuilder(
                animation: _hint,
                builder: (context, _) => CustomPaint(
                  painter: _HingePainter(v, still ? 0 : _hint.value),
                ),
              ),
              DeviceVisualKind.safe => TweenAnimationBuilder<double>(
                tween: Tween(end: v.progress),
                duration: quick,
                builder: (context, p, _) => AnimatedScale(
                  scale: v.solved ? 1.08 : 1,
                  duration: quick,
                  child: CustomPaint(painter: _SafePainter(v, p)),
                ),
              ),
              DeviceVisualKind.otherSide => _FlipCard(
                visual: v,
                duration: quick,
              ),
              DeviceVisualKind.mind => TweenAnimationBuilder<double>(
                tween: Tween(end: v.progress),
                duration: quick,
                builder: (context, p, _) => Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _MindPainter(p, v.revealed)),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: side * 0.16),
                        child: AnimatedSwitcher(
                          duration: quick,
                          child: BalancedText(
                            v.label ?? '',
                            key: ValueKey(v.label),
                            style: Ays.label(
                              side * 0.085,
                              color: v.revealed ? Ays.correct : Ays.ink,
                            ),
                            maxLines: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            },
          ),
        );
      },
    );
  }
}

/// A phone seen from the side, folding around its hinge. The green arc is
/// the target window; the faint ghost panel breathes toward it as the hint.
class _HingePainter extends CustomPainter {
  _HingePainter(this.v, this.hint);

  final DeviceVisual v;
  final double hint;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final hinge = Offset(size.width / 2, size.height * 0.68);
    final len = s * 0.38;
    final stroke = s * 0.045;
    final panel = Paint()
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // Target window.
    final arc = Paint()
      ..color = Ays.correct.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.09;
    canvas.drawArc(
      Rect.fromCircle(center: hinge, radius: len * 0.7),
      -math.pi * 5 / 9, // 80°..150°, BEND OVER's window
      math.pi * 7 / 18,
      false,
      arc,
    );

    // Fixed bottom panel.
    canvas.drawLine(hinge, hinge.translate(-len, 0), panel..color = Ays.inkDim);

    // Ghost: the hint, breathing between flat and 90°.
    final ghostAngle = 180 - 90 * hint;
    _drawPanel(
      canvas,
      hinge,
      len,
      ghostAngle,
      panel..color = Ays.purple.withValues(alpha: 0.35),
    );

    // The live panel.
    final angle = v.angleDegrees ?? (v.progress >= 1 ? 115 : 180);
    final live = Color.lerp(Ays.ink, Ays.correct, v.progress)!;
    _drawPanel(canvas, hinge, len, angle, panel..color = live);
    canvas.drawCircle(hinge, stroke * 0.8, Paint()..color = live);
  }

  void _drawPanel(
    Canvas canvas,
    Offset hinge,
    double len,
    double angle,
    Paint p,
  ) {
    // 180° = flat (panel pointing right), 0° = closed (on top of the base).
    final rad = math.pi - angle * math.pi / 180;
    canvas.drawLine(
      hinge,
      hinge + Offset(math.cos(rad) * len, -math.sin(rad) * len),
      p,
    );
  }

  @override
  bool shouldRepaint(_HingePainter old) =>
      old.hint != hint ||
      old.v.angleDegrees != v.angleDegrees ||
      old.v.progress != v.progress;
}

/// A safe dial: ticks, a needle that follows the hinge, a ring that warms
/// from red to green with closeness, a bolt that slides open when solved.
class _SafePainter extends CustomPainter {
  _SafePainter(this.v, this.p);

  final DeviceVisual v;
  final double p;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.4;
    final warm = v.solved
        ? Ays.correct
        : Color.lerp(Ays.wrong, Ays.correct, p)!;
    canvas.drawCircle(c, r, Paint()..color = Ays.surfaceHigh);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = warm
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1,
    );
    final tick = Paint()
      ..color = Ays.inkDim
      ..strokeWidth = r * 0.025;
    for (var i = 0; i < 36; i++) {
      final a = i * math.pi * 2 / 36;
      final inner = i % 3 == 0 ? 0.74 : 0.8;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * r * inner,
        c + Offset(math.cos(a), math.sin(a)) * r * 0.86,
        tick,
      );
    }
    final angle = v.angleDegrees ?? p * 180;
    final needle = -math.pi / 2 + angle * math.pi / 90; // two turns per 180°
    canvas.drawLine(
      c,
      c + Offset(math.cos(needle), math.sin(needle)) * r * 0.66,
      Paint()
        ..color = Ays.ink
        ..strokeWidth = r * 0.06
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(c, r * 0.12, Paint()..color = warm);
    // Bolt: slides right when unlocked.
    final boltX = v.solved ? r * 1.25 : r * 0.92;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c + Offset(boltX, 0),
          width: r * 0.3,
          height: r * 0.16,
        ),
        Radius.circular(r * 0.05),
      ),
      Paint()..color = warm,
    );
  }

  @override
  bool shouldRepaint(_SafePainter old) =>
      old.p != p ||
      old.v.solved != v.solved ||
      old.v.angleDegrees != v.angleDegrees;
}

/// The incomplete code on one face, the missing digit on the other. Flips
/// when the display configuration changes.
class _FlipCard extends StatelessWidget {
  const _FlipCard({required this.visual, required this.duration});

  final DeviceVisual visual;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: visual.revealed ? 1 : 0),
      duration: duration == Duration.zero
          ? Duration.zero
          : const Duration(milliseconds: 420),
      builder: (context, t, _) {
        final showBack = t >= 0.5;
        final rot = t * math.pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(showBack ? rot - math.pi : rot),
          child: FractionallySizedBox(
            widthFactor: 0.8,
            heightFactor: 0.62,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: showBack
                    ? Ays.correct.withValues(alpha: 0.18)
                    : Ays.surfaceHigh,
                borderRadius: Ays.radius,
                border: Border.all(
                  color: showBack ? Ays.correct : Ays.inkDim,
                  width: 3,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: BalancedText(
                    visual.label ?? '',
                    style: Ays.title(64)
                        .copyWith(color: showBack ? Ays.correct : Ays.ink),
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Two hemispheres that drift apart as the hinge opens.
class _MindPainter extends CustomPainter {
  _MindPainter(this.p, this.revealed);

  final double p;
  final bool revealed;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.36;
    final gap = r * 0.5 * p;
    final paint = Paint()
      ..color = (revealed ? Ays.purple : Ays.surfaceHigh).withValues(
        alpha: 0.85,
      );
    canvas.drawArc(
      Rect.fromCircle(center: c.translate(-gap, 0), radius: r),
      math.pi / 2,
      math.pi,
      true,
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c.translate(gap, 0), radius: r),
      -math.pi / 2,
      math.pi,
      true,
      paint,
    );
  }

  @override
  bool shouldRepaint(_MindPainter old) =>
      old.p != p || old.revealed != revealed;
}
