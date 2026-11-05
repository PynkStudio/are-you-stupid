import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Keeps the game's portrait composition when the system hands it a landscape
/// window, which iPhone Duo's inner display does whatever the app asks for
/// ([[Rendering Pipeline]] → Portrait frame).
///
/// The app still fills the display, so iOS reports the real size class. Only
/// the content stays in a centered portrait column, with the page background
/// continuing behind it. Screens below see the column as their whole screen.
class PortraitFrame extends StatelessWidget {
  const PortraitFrame({super.key, required this.enabled, required this.child});

  /// Width of the column, as a share of the height. Matches the usable part of
  /// iPhone Duo's cover display.
  static const widthPerHeight = 0.72;

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    if (!enabled || size.width <= size.height) return child;
    final width = math.min(size.width, size.height * widthPerHeight);
    // The column sits clear of the side insets (the status bar on the right).
    final side = (size.width - width) / 2;
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: Ays.pageGradient),
      child: Center(
        child: SizedBox(
          width: width,
          height: size.height,
          child: MediaQuery(
            data: media.copyWith(
              size: Size(width, size.height),
              padding: media.padding.copyWith(
                left: math.max(0, media.padding.left - side),
                right: math.max(0, media.padding.right - side),
              ),
              viewPadding: media.viewPadding.copyWith(
                left: math.max(0, media.viewPadding.left - side),
                right: math.max(0, media.viewPadding.right - side),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
