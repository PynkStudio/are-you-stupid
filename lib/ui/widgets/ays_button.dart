import 'package:flutter/material.dart';

import '../theme.dart';

/// The one button style used across menus. Big, flat, obvious.
class AysButton extends StatefulWidget {
  const AysButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = Ays.ink,
    this.textColor = Ays.bg,
    this.height = 78,
    this.fontSize = 30,
    this.icon,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color textColor;
  final double height;
  final double fontSize;
  final String? icon;
  final bool outlined;

  @override
  State<AysButton> createState() => _AysButtonState();
}

class _AysButtonState extends State<AysButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 70),
        child: Container(
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.outlined ? Colors.transparent : widget.color,
            borderRadius: Ays.radius,
            border: widget.outlined
                ? Border.all(color: Ays.surfaceHigh, width: 2)
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                widget.icon == null
                    ? widget.label
                    : '${widget.icon}  ${widget.label}',
                style: Ays.label(
                  widget.fontSize,
                  color: widget.outlined ? Ays.ink : widget.textColor,
                  weight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
