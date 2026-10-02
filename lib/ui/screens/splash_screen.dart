import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Shown immediately at boot, before [AppServices.boot] resolves (ads SDK,
/// purchases, prefs — can take a couple of seconds). No localized strings
/// on purpose: locale lives in the settings AppServices loads, which isn't
/// ready yet — see `AreYouStupidApp`. Pure widgets, no images (matches the
/// zero-external-assets pillar).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Ays.bg,
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final bounce = 0.5 - 0.5 * math.cos(t * 2 * math.pi);
            final tilt = math.sin(t * 2 * math.pi) * 0.09;
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                _Spark(t: t, delay: 0.00, angle: -1.9, distance: 74),
                _Spark(t: t, delay: 0.33, angle: -0.5, distance: 80),
                _Spark(t: t, delay: 0.66, angle: 0.9, distance: 76),
                Transform.rotate(
                  angle: tilt,
                  child: Transform.scale(
                    scale: 0.92 + 0.16 * bounce,
                    child: const Text('🧠', style: TextStyle(fontSize: 88)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One of the little bursts that flick outward and fade, echoing the
/// exclamation marks around the app icon.
class _Spark extends StatelessWidget {
  const _Spark({
    required this.t,
    required this.delay,
    required this.angle,
    required this.distance,
  });

  final double t;
  final double delay;
  final double angle;
  final double distance;

  @override
  Widget build(BuildContext context) {
    final local = (t - delay) % 1.0;
    final opacity = local < 0.5 ? local / 0.5 : 1 - (local - 0.5) / 0.5;
    final reach = Curves.easeOut.transform(math.min(local / 0.5, 1.0));
    return Transform.translate(
      offset: Offset(
        math.cos(angle) * distance * reach,
        math.sin(angle) * distance * reach,
      ),
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: const Text(
          '✦',
          style: TextStyle(fontSize: 18, color: Ays.yellow),
        ),
      ),
    );
  }
}
