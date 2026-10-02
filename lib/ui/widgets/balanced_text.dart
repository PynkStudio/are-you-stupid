import 'package:flutter/material.dart';

/// Headline text that never breaks a word and wraps symmetrically.
///
/// Three rules, in order:
/// 1. **Never split a word.** If the longest word does not fit the width on
///    its own, the font shrinks until it does (`IMPOSTAZIONI`, never
///    `IMPOSTAZION / I`).
/// 2. **Respect [maxLines].** If the text still needs more lines than
///    allowed, the font keeps shrinking (down to [minScale]). With
///    `maxLines: 1` this is a plain "fit the title on one line".
/// 3. **Balance the lines.** Once the line count is fixed, the box is
///    narrowed to the smallest width that keeps that count, so the lines come
///    out even (`CONGRATULATIONS, / I GUESS` instead of a lone orphan word).
///
/// Pass [maxWidth] when the widget sits where a [LayoutBuilder] cannot be
/// used (e.g. under a `FittedBox`); otherwise the incoming constraints are
/// measured.
class BalancedText extends StatelessWidget {
  const BalancedText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines = 2,
    this.textAlign = TextAlign.center,
    this.minScale = 0.4,
    this.maxWidth,
  });

  final String text;
  final TextStyle style;
  final int maxLines;
  final TextAlign textAlign;

  /// Smallest font size allowed, as a fraction of `style.fontSize`.
  final double minScale;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    if (maxWidth != null) return _fitted(context, maxWidth!);
    return LayoutBuilder(
      builder: (context, box) => _fitted(context, box.maxWidth),
    );
  }

  Widget _fitted(BuildContext context, double width) {
    if (!width.isFinite || text.trim().isEmpty) {
      return Text(text, style: style, textAlign: textAlign);
    }
    final layout = balance(
      text,
      style,
      width,
      maxLines: maxLines,
      minScale: minScale,
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    );
    return Align(
      alignment: switch (textAlign) {
        TextAlign.left || TextAlign.start => Alignment.centerLeft,
        TextAlign.right || TextAlign.end => Alignment.centerRight,
        _ => Alignment.center,
      },
      heightFactor: 1,
      child: SizedBox(
        width: layout.width,
        child: Text(
          text,
          style: layout.style,
          textAlign: textAlign,
          maxLines: layout.lines,
          softWrap: layout.lines > 1,
          overflow: TextOverflow.visible,
        ),
      ),
    );
  }

  /// Pure layout maths, exposed for tests.
  static BalancedLayout balance(
    String text,
    TextStyle style,
    double maxWidth, {
    int maxLines = 2,
    double minScale = 0.4,
    TextScaler textScaler = TextScaler.noScaling,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    // Rounding slack: a width measured as 120.3 must not wrap at 120.3.
    const slack = 1.0;
    final base = style.fontSize ?? 14;
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);

    TextPainter paint(TextStyle s, double w) => TextPainter(
          text: TextSpan(text: text, style: s),
          textDirection: textDirection,
          textScaler: textScaler,
        )..layout(maxWidth: w);

    double widest(TextStyle s) {
      var max = 0.0;
      for (final w in words) {
        final p = TextPainter(
          text: TextSpan(text: w, style: s),
          textDirection: textDirection,
          textScaler: textScaler,
          maxLines: 1,
        )..layout();
        if (p.width > max) max = p.width;
        p.dispose();
      }
      return max;
    }

    int linesAt(TextStyle s, double w) {
      final p = paint(s, w);
      final n = p.computeLineMetrics().length;
      p.dispose();
      return n;
    }

    var size = base;
    var s = style.copyWith(fontSize: size);
    var word = widest(s);
    var lines = 1;
    while (true) {
      if (word + slack <= maxWidth) {
        lines = linesAt(s, maxWidth);
        if (lines <= maxLines) break;
      }
      final next = word + slack > maxWidth
          ? size * (maxWidth / (word + slack)).clamp(0.5, 0.97)
          : size * 0.94;
      if (next < base * minScale) {
        // Floor reached: accept what we have rather than vanish.
        size = base * minScale;
        s = style.copyWith(fontSize: size);
        word = widest(s);
        lines = linesAt(s, maxWidth).clamp(1, maxLines);
        break;
      }
      size = next;
      s = style.copyWith(fontSize: size);
      word = widest(s);
    }

    if (lines <= 1) {
      return BalancedLayout(s, maxWidth, 1);
    }

    // Narrowest width that keeps the same line count → even lines.
    var lo = word;
    var hi = maxWidth;
    for (var i = 0; i < 14 && hi - lo > 0.5; i++) {
      final mid = (lo + hi) / 2;
      if (linesAt(s, mid) <= lines) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return BalancedLayout(s, (hi + slack).clamp(0, maxWidth), lines);
  }
}

class BalancedLayout {
  const BalancedLayout(this.style, this.width, this.lines);

  final TextStyle style;
  final double width;
  final int lines;
}
