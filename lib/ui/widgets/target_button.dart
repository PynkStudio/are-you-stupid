import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/challenge.dart';
import '../theme.dart';

/// Draws one [TargetSpec]. Huge, flat, instant press feedback.
class TargetButton extends StatefulWidget {
  const TargetButton({
    super.key,
    required this.spec,
    required this.onDown,
    required this.onUp,
    this.dense = false,
  });

  final TargetSpec spec;
  final VoidCallback onDown;
  final VoidCallback onUp;

  /// Smaller label, used in 6-button grids.
  final bool dense;

  @override
  State<TargetButton> createState() => _TargetButtonState();
}

class _TargetButtonState extends State<TargetButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    if (spec.hidden) return const SizedBox.shrink();

    final paint = Ays.of(spec.color);
    final labelColor = spec.textColor != null
        ? Ays.of(spec.textColor!)
        : Ays.inkOn(spec.color);

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        setState(() => _pressed = true);
        widget.onDown();
      },
      onPointerUp: (_) {
        if (mounted) setState(() => _pressed = false);
        widget.onUp();
      },
      onPointerCancel: (_) {
        if (mounted) setState(() => _pressed = false);
        widget.onUp();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          return Center(
            child: Transform.translate(
              offset: Offset(
                spec.dx * constraints.maxWidth,
                spec.dy * constraints.maxHeight,
              ),
              child: Transform.rotate(
                angle: spec.rotation,
                child: AnimatedScale(
                  scale: _pressed ? 0.94 : 1.0,
                  duration: const Duration(milliseconds: 70),
                  child: Opacity(
                    opacity: spec.opacity,
                    child: _Shape(
                      shape: spec.shape,
                      color: paint,
                      width: constraints.maxWidth * spec.scale,
                      height: constraints.maxHeight * spec.scale,
                      side: side * spec.scale,
                      child: spec.label.isEmpty
                          ? null
                          : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  spec.label,
                                  textAlign: TextAlign.center,
                                  style: Ays.label(
                                    widget.dense ? 20 : 30,
                                    color: labelColor,
                                    weight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Shape extends StatelessWidget {
  const _Shape({
    required this.shape,
    required this.color,
    required this.width,
    required this.height,
    required this.side,
    this.child,
  });

  final TargetShape shape;
  final Color color;
  final double width;
  final double height;
  final double side;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    switch (shape) {
      case TargetShape.rect:
        return Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, borderRadius: Ays.radius),
          child: child,
        );
      case TargetShape.circle:
        return Container(
          width: side,
          height: side,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: child,
        );
      case TargetShape.triangle:
      case TargetShape.diamond:
        return SizedBox(
          width: side,
          height: side,
          child: CustomPaint(
            painter: _PolyPainter(shape: shape, color: color),
            child: Center(child: child),
          ),
        );
    }
  }
}

class _PolyPainter extends CustomPainter {
  const _PolyPainter({required this.shape, required this.color});

  final TargetShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final path = Path();
    if (shape == TargetShape.triangle) {
      path
        ..moveTo(size.width / 2, size.height * 0.06)
        ..lineTo(size.width * 0.96, size.height * 0.94)
        ..lineTo(size.width * 0.04, size.height * 0.94)
        ..close();
    } else {
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(0, size.height / 2)
        ..close();
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_PolyPainter old) =>
      old.color != color || old.shape != shape;
}
