import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Shown immediately at boot, before [AppServices.boot] resolves (ads SDK,
/// purchases, prefs — can take a couple of seconds). No localized strings
/// on purpose: locale lives in the settings AppServices loads, which isn't
/// ready yet — see `AreYouStupidApp`. Pure widgets and painters, no images
/// (matches the zero-external-assets pillar).
///
/// The star is the app icon's mascot, painted live: a pink brain with
/// mismatched googly eyes that hops on a glowing yellow puddle, looks around,
/// blinks, and pops the icon's yellow sparks on every landing. Under it, a
/// row of game-colour loading dots where the last one is always late — the
/// game's joke, before the game even starts.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// One full hop / look-around / blink cycle.
  static const loop = Duration(milliseconds: 2400);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _loop;
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: SplashScreen.loop)
      ..repeat();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _loop.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: Ays.pageGradient),
      child: LayoutBuilder(
        builder: (context, box) {
          final stage = math.min(
            340.0,
            math.min(box.maxWidth * 0.84, box.maxHeight * 0.46),
          );
          return AnimatedBuilder(
            animation: Listenable.merge([_loop, _enter]),
            builder: (context, _) {
              final t = still ? 0.12 : _loop.value;
              final e = still ? 1.0 : _enter.value;
              return Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _GlowPainter(t: t, enter: e)),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: Curves.easeOut.transform(
                            math.min(e * 1.6, 1.0),
                          ),
                          child: Transform.scale(
                            scale: Curves.elasticOut.transform(e) * 0.4 + 0.6,
                            child: SizedBox.square(
                              dimension: stage,
                              child: CustomPaint(
                                painter: _MascotPainter(t: t),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: stage * 0.1),
                        Opacity(
                          opacity: Curves.easeIn.transform(e),
                          child: _LoadingDots(t: t, size: stage * 0.05),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------------------- timing

/// Vertical hop in the 0..1 loop: 0 = resting, 1 = top of the jump.
double _hop(double t) {
  if (t < 0.12 || t > 0.52) return 0;
  final p = (t - 0.12) / 0.40;
  return math.sin(p * math.pi);
}

/// Squash on take-off and landing: positive = squashed flat.
double _squash(double t) {
  double pulse(double at, double width, double amount) {
    final d = (t - at).abs();
    return d > width ? 0 : amount * math.cos(d / width * math.pi / 2);
  }

  return pulse(0.09, 0.07, 0.10) + pulse(0.56, 0.08, 0.16);
}

/// Sparks burst after the landing.
double _burst(double t) {
  if (t < 0.52 || t > 0.86) return -1;
  return (t - 0.52) / 0.34;
}

double _smooth(double a, double b, double x) {
  final p = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return p * p * (3 - 2 * p);
}

/// Where the pupils look, in -1..1 per axis.
Offset _look(double t) {
  // Up while airborne, then left, then right, then a dumb cross-eyed stare.
  final up = Offset(0.15, -0.85);
  final left = const Offset(-0.85, 0.2);
  final right = const Offset(0.85, 0.15);
  Offset lerp(Offset a, Offset b, double k) => Offset.lerp(a, b, k)!;
  if (t < 0.10) return lerp(right, up, _smooth(0.0, 0.10, t));
  if (t < 0.55) return up;
  if (t < 0.70) return lerp(up, left, _smooth(0.55, 0.62, t));
  return lerp(left, right, _smooth(0.78, 0.84, t));
}

/// Eye openness: 1 open, 0 shut.
double _blink(double t) {
  const at = 0.73;
  final d = (t - at).abs();
  return d > 0.03 ? 1 : d / 0.03;
}

// ----------------------------------------------------------------- painters

/// Soft pink/yellow stage light behind the mascot, breathing with the hop.
class _GlowPainter extends CustomPainter {
  _GlowPainter({required this.t, required this.enter});

  final double t;
  final double enter;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset(0, -size.height * 0.04));
    final r = size.shortestSide * (0.62 + 0.04 * math.sin(t * 2 * math.pi));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Ays.pink.withValues(alpha: 0.20 * enter),
            Ays.purple.withValues(alpha: 0.07 * enter),
            Ays.bg.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.t != t || old.enter != enter;
}

/// The app-icon brain, drawn in a square box.
class _MascotPainter extends CustomPainter {
  _MascotPainter({required this.t});

  final double t;

  static const _outline = Color(0xFF14070E);
  static const _pinkLight = Color(0xFFFF9BCB);
  static const _pinkDark = Color(0xFFD9327F);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 240; // design grid is 240x240
    canvas.save();
    canvas.scale(s);

    final hop = _hop(t);
    final squash = _squash(t);
    const groundY = 206.0;

    _paintPuddle(canvas, hop, groundY);
    _paintSparks(canvas);

    // Brain body: anchored at its feet so squash plants it on the puddle.
    canvas.save();
    canvas.translate(120, groundY - 14 - hop * 46);
    canvas.rotate(math.sin(t * 2 * math.pi * 2) * 0.035 + hop * -0.06);
    canvas.scale(1 + squash * 0.9, 1 - squash);
    canvas.translate(-120, -(groundY - 14));
    _paintBrain(canvas);
    _paintFace(canvas, hop);
    canvas.restore();

    canvas.restore();
  }

  void _paintPuddle(Canvas canvas, double hop, double y) {
    final w = 150 - hop * 46;
    final rect = Rect.fromCenter(
      center: Offset(120, y),
      width: w,
      height: w * 0.22,
    );
    // Glow.
    canvas.drawOval(
      rect.inflate(16),
      Paint()
        ..color = Ays.yellow.withValues(alpha: 0.18 - hop * 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawOval(rect, Paint()..color = Ays.yellow);
    canvas.drawOval(
      Rect.fromCenter(
        center: rect.center.translate(0, 2),
        width: rect.width * 0.68,
        height: rect.height * 0.5,
      ),
      Paint()..color = const Color(0xFFE0A800),
    );
  }

  void _paintSparks(Canvas canvas) {
    final b = _burst(t);
    if (b < 0) return;
    final reach = Curves.easeOutBack.transform(math.min(b * 2.2, 1.0));
    final fade = b < 0.6 ? 1.0 : 1 - (b - 0.6) / 0.4;
    final paint = Paint()..color = Ays.yellow.withValues(alpha: fade);
    // Two fans of wedges, like the icon: (angle, length) from the head.
    const rays = [
      (-2.45, 30.0),
      (-2.95, 22.0),
      (2.85, 18.0),
      (-0.69, 30.0),
      (-0.19, 22.0),
      (0.29, 18.0),
    ];
    const head = Offset(120, 112);
    for (final (angle, len) in rays) {
      final dir = Offset(math.cos(angle), math.sin(angle));
      final normal = Offset(-dir.dy, dir.dx);
      final start = head + dir * (82 + 10 * reach);
      final tip = start + dir * len * reach;
      final base = start - dir * 4;
      final path = Path()
        ..moveTo(base.dx + normal.dx * 6, base.dy + normal.dy * 6)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(base.dx - normal.dx * 6, base.dy - normal.dy * 6)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  Path _brainPath() {
    // Lobes, unioned so the outline is one clean silhouette.
    const lobes = [
      (Offset(72, 112), 34.0),
      (Offset(92, 80), 34.0),
      (Offset(130, 72), 36.0),
      (Offset(164, 96), 32.0),
      (Offset(172, 132), 28.0),
      (Offset(66, 146), 28.0),
      (Offset(120, 140), 50.0),
      (Offset(150, 162), 30.0),
      (Offset(92, 166), 30.0),
    ];
    var path = Path();
    for (final (c, r) in lobes) {
      path = Path.combine(
        PathOperation.union,
        path,
        Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      );
    }
    return path;
  }

  void _paintBrain(Canvas canvas) {
    final brain = _brainPath();
    final bounds = brain.getBounds();

    canvas.drawPath(
      brain,
      Paint()
        ..color = _outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      brain,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [_pinkLight, Ays.pink, _pinkDark],
          stops: const [0, 0.5, 1],
        ).createShader(bounds),
    );

    canvas.save();
    canvas.clipPath(brain);
    final fold = Paint()
      ..color = _pinkDark.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    // Gyri: a few lazy squiggles away from the eyes.
    final folds = [
      Path()
        ..moveTo(88, 60)
        ..quadraticBezierTo(104, 70, 100, 86),
      Path()
        ..moveTo(128, 46)
        ..quadraticBezierTo(122, 62, 138, 70),
      Path()
        ..moveTo(170, 74)
        ..quadraticBezierTo(158, 88, 172, 104),
      Path()
        ..moveTo(56, 98)
        ..quadraticBezierTo(70, 104, 62, 120),
      Path()
        ..moveTo(110, 168)
        ..quadraticBezierTo(122, 160, 134, 176),
      Path()
        ..moveTo(176, 136)
        ..quadraticBezierTo(164, 144, 168, 158),
      Path()
        ..moveTo(70, 160)
        ..quadraticBezierTo(82, 152, 92, 164),
    ];
    for (final f in folds) {
      canvas.drawPath(f, fold);
    }
    // Glossy highlight, top-left, like the icon's clay look.
    canvas.drawOval(
      const Rect.fromLTWH(70, 52, 54, 26),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.restore();
  }

  void _paintFace(Canvas canvas, double hop) {
    final look = _look(t);
    final open = _blink(t);
    // Mismatched eyes: the right one is bigger, as in the icon.
    _paintEye(canvas, const Offset(98, 120), 22, 25, look, open);
    _paintEye(canvas, const Offset(146, 114), 25, 28, look, open);

    // Worried brows that shoot up while airborne.
    final lift = hop * 8;
    final brow = Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(78, 96 - lift * 0.6)
        ..quadraticBezierTo(92, 84 - lift, 112, 88 - lift),
      brow,
    );
    canvas.drawPath(
      Path()
        ..moveTo(134, 80 - lift)
        ..quadraticBezierTo(150, 74 - lift, 166, 84 - lift * 0.6),
      brow,
    );
  }

  void _paintEye(
    Canvas canvas,
    Offset c,
    double rx,
    double ry,
    Offset look,
    double open,
  ) {
    final h = math.max(ry * 2 * open, 2.0);
    final eye = Rect.fromCenter(center: c, width: rx * 2, height: h);
    if (open < 0.15) {
      canvas.drawLine(
        c.translate(-rx * 0.8, 0),
        c.translate(rx * 0.8, 0),
        Paint()
          ..color = _outline
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    canvas.drawOval(eye.inflate(3.5), Paint()..color = _outline);
    canvas.drawOval(eye, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipPath(Path()..addOval(eye));
    final pr = rx * 0.42;
    final pupil = c + Offset(look.dx * (rx - pr - 3), look.dy * (ry - pr - 3));
    canvas.drawCircle(pupil, pr, Paint()..color = _outline);
    canvas.drawCircle(
      pupil.translate(-pr * 0.35, -pr * 0.4),
      pr * 0.3,
      Paint()..color = Colors.white,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MascotPainter old) => old.t != t;
}

// ------------------------------------------------------------ loading dots

/// Game-colour dots doing a wave; the last one is always a beat late.
class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.t, required this.size});

  final double t;
  final double size;

  static const _colors = [Ays.red, Ays.blue, Ays.green, Ays.yellow, Ays.pink];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _colors.length; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.45),
            child: Transform.translate(
              offset: Offset(0, -_lift(i) * size * 1.4),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: _colors[i],
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
  }

  double _lift(int i) {
    final last = i == _colors.length - 1;
    // Twice per loop; the last dot misses its cue by half a wave.
    final phase = (t * 2 - i * 0.12 - (last ? 0.28 : 0)) % 1.0;
    return phase < 0.35 ? math.sin(phase / 0.35 * math.pi) : 0;
  }
}
