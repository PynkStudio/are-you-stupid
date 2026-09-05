import 'package:flutter/material.dart';

import '../core/challenge.dart';

/// Everything visual is generated: no images, no fonts, no assets.
class Ays {
  Ays._();

  // ------------------------------------------------------------------ colors
  static const bg = Color(0xFF0B0B0F);
  static const bgTop = Color(0xFF15151D);
  static const surface = Color(0xFF1C1C24);
  static const surfaceHigh = Color(0xFF2A2A34);
  static const ink = Color(0xFFF7F7FA);
  static const inkDim = Color(0xFF8A8A99);

  static const red = Color(0xFFFF3B3B);
  static const blue = Color(0xFF2F80FF);
  static const green = Color(0xFF25D366);
  static const yellow = Color(0xFFFFD400);
  static const purple = Color(0xFFA855F7);
  static const orange = Color(0xFFFF8A00);
  static const pink = Color(0xFFFF4FA3);

  static const correct = green;
  static const wrong = red;
  static const warning = yellow;

  static Color of(GameColor c) => switch (c) {
        GameColor.red => red,
        GameColor.blue => blue,
        GameColor.green => green,
        GameColor.yellow => yellow,
        GameColor.purple => purple,
        GameColor.orange => orange,
        GameColor.pink => pink,
        GameColor.white => ink,
        GameColor.slate => surfaceHigh,
      };

  /// Readable label color on top of a given paint.
  static Color inkOn(GameColor c) => switch (c) {
        GameColor.yellow || GameColor.white || GameColor.green => const Color(0xFF0B0B0F),
        _ => ink,
      };

  // -------------------------------------------------------------------- type
  // System font on purpose: zero assets, instant load.
  static const String? _family = null;

  static TextStyle title(double size) => TextStyle(
        fontFamily: _family,
        fontSize: size,
        height: 0.92,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.5,
        color: ink,
      );

  static TextStyle instruction(double size) => TextStyle(
        fontFamily: _family,
        fontSize: size,
        height: 1.0,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.8,
        color: ink,
      );

  static TextStyle label(double size, {Color? color, FontWeight? weight}) =>
      TextStyle(
        fontFamily: _family,
        fontSize: size,
        fontWeight: weight ?? FontWeight.w800,
        letterSpacing: 0.6,
        color: color ?? ink,
      );

  static TextStyle mono(double size, {Color? color}) => TextStyle(
        fontFamily: _family,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: color ?? inkDim,
      );

  // ------------------------------------------------------------------ shapes
  static const radius = BorderRadius.all(Radius.circular(26));
  static const radiusSmall = BorderRadius.all(Radius.circular(16));

  static const pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bg],
  );

  static ThemeData theme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: ink,
        surface: surface,
        error: red,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
