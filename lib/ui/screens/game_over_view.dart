import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/roasts.dart';
import '../../i18n/strings.dart';
import '../../services/app_services.dart';
import '../theme.dart';
import '../widgets/ays_button.dart';
import '../widgets/balanced_text.dart';

/// Designed to be screenshotted: the verdict, the big number, and the
/// stupidly simple instruction that ended the run — readable at thumbnail
/// size in a 9:16 clip ([[Virality and Sharing]]).
///
/// The headline is the run's verdict: an AI line written from the run's own
/// facts when the model delivered one in time ([[AI Commentary]] →
/// `gameOver`), the static Game Over roast otherwise. Nothing on the card
/// says which — no AI wallpaper ([[Quality Neutrality and Guardrails]]).
class GameOverView extends StatefulWidget {
  const GameOverView({
    super.key,
    required this.level,
    required this.best,
    required this.isRecord,
    required this.canContinue,
    required this.onRetry,
    required this.onContinue,
    required this.onQuit,
    this.bestStreak = 0,
    this.failedInstruction,
    this.failReason,
    this.aiVerdict,
  });

  final int level;
  final int best;
  final bool isRecord;
  final bool canContinue;
  final VoidCallback onRetry;
  final VoidCallback onContinue;
  final VoidCallback onQuit;

  /// Best fast streak of the run; the streak chip only shows from 3 up,
  /// matching the in-game 🔥 counter.
  final int bestStreak;

  /// The instruction on screen when the run ended ("KILLED BY").
  final String? failedInstruction;

  /// The challenge's one-line explanation of the failure.
  final String? failReason;

  /// The AI verdict, when it has arrived. May arrive after the card is up:
  /// it is only swapped in while the input lock still holds, so a line
  /// never changes under a player who is already reading/tapping.
  final String? aiVerdict;

  @override
  State<GameOverView> createState() => _GameOverViewState();
}

class _GameOverViewState extends State<GameOverView>
    with SingleTickerProviderStateMixin {
  /// Buttons ignore input for a beat after the card appears, so the tail of
  /// a tap-mashing run can't hit TRY AGAIN / CONTINUE / HOME by accident.
  static const _inputLock = Duration(milliseconds: 600);

  /// Staggered entrance; finishes inside [_inputLock] so the card is fully
  /// built by the time it accepts taps.
  static const _entrance = Duration(milliseconds: 560);

  late final AnimationController _intro =
      AnimationController(vsync: this, duration: _entrance)..forward();

  bool _armed = false;
  Timer? _armTimer;
  String? _headline;

  @override
  void initState() {
    super.initState();
    _armTimer = Timer(_inputLock, () {
      if (mounted) setState(() => _armed = true);
    });
  }

  @override
  void didUpdateWidget(GameOverView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_armed && oldWidget.aiVerdict == null && widget.aiVerdict != null) {
      _headline = widget.aiVerdict!.toUpperCase();
    }
  }

  @override
  void dispose() {
    _armTimer?.cancel();
    _intro.dispose();
    super.dispose();
  }

  late final String _roast = Roasts.gameOver(
    allowSpicy: AppServices.of(context).settings.roastsEnabled,
    locale: AppServices.of(context).settings.locale,
  );

  Future<void> _share() async {
    final services = AppServices.of(context);
    services.sound.button();
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    await services.share.shareResult(
      widget.level,
      best: widget.best,
      origin: origin,
      locale: services.settings.locale,
    );
  }

  /// One entrance beat: fades and lifts in during its slice of [_intro].
  Widget _beat(double start, Widget child) {
    final curve = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, (start + 0.55).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      child: child,
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - curve.value)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppServices.of(context).settings.locale;
    String t(String key, [Map<String, String>? args]) =>
        Strings.t(locale, key, args);
    final headline =
        _headline ??= widget.aiVerdict?.toUpperCase() ?? _roast;
    final instruction = widget.failedInstruction?.trim();

    return AbsorbPointer(
      absorbing: !_armed,
      child: Container(
        color: Ays.bg,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t('app.title'), style: Ays.mono(13)),
                    Text(t('ui.game_over.title'),
                        style: Ays.mono(13, color: Ays.red)),
                  ],
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => Center(
                      // Scales the whole block down on short screens instead
                      // of overflowing; never scales up.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: box.maxWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _beat(
                                0,
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: BalancedText(
                                    headline,
                                    key: ValueKey(headline),
                                    maxLines: 3,
                                    maxWidth: box.maxWidth,
                                    style: Ays.title(
                                      headline.length <= 18 ? 40 : 30,
                                    ).copyWith(color: Ays.red, height: 1.0),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              _beat(0.15, _ScoreCard(
                                level: widget.level,
                                best: widget.best,
                                isRecord: widget.isRecord,
                                reachedLabel: t('ui.game_over.i_reached'),
                                levelLabel: (n) =>
                                    t('ui.game_over.level', {'n': '$n'}),
                                newBestLabel: t('ui.game_over.new_best'),
                                bestLabel: t('ui.game_over.best',
                                    {'n': '${widget.best}'}),
                                streakLabel: widget.bestStreak >= 3
                                    ? t('ui.game_over.streak',
                                        {'n': '${widget.bestStreak}'})
                                    : null,
                                intro: _intro,
                              )),
                              if (instruction != null && instruction.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _beat(0.3, _KilledByCard(
                                  label: t('ui.game_over.killed_by'),
                                  instruction: instruction,
                                  reason: widget.failReason,
                                )),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                AysButton(
                  label: t('ui.game_over.try_again'),
                  height: 84,
                  fontSize: 34,
                  onTap: widget.onRetry,
                ),
                if (widget.canContinue) ...[
                  const SizedBox(height: 12),
                  AysButton(
                    label: t('ui.game_over.continue_btn'),
                    icon: '▶',
                    height: 60,
                    fontSize: 20,
                    color: Ays.green,
                    textColor: Ays.bg,
                    onTap: widget.onContinue,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AysButton(
                        label: t('ui.game_over.share'),
                        height: 56,
                        fontSize: 17,
                        outlined: true,
                        onTap: _share,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 96,
                      child: AysButton(
                        label: t('ui.game_over.home'),
                        height: 56,
                        fontSize: 15,
                        outlined: true,
                        onTap: widget.onQuit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The number people screenshot: level reached (counts up during the
/// entrance), best / new-best, and the fast-streak chip.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.level,
    required this.best,
    required this.isRecord,
    required this.reachedLabel,
    required this.levelLabel,
    required this.newBestLabel,
    required this.bestLabel,
    required this.streakLabel,
    required this.intro,
  });

  final int level;
  final int best;
  final bool isRecord;
  final String reachedLabel;
  final String Function(int) levelLabel;
  final String newBestLabel;
  final String bestLabel;
  final String? streakLabel;
  final Animation<double> intro;

  @override
  Widget build(BuildContext context) {
    final accent = isRecord ? Ays.warning : Ays.surfaceHigh;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Ays.surface,
        borderRadius: Ays.radius,
        border: Border.all(color: accent, width: isRecord ? 2 : 1),
      ),
      child: Column(
        children: [
          Text(reachedLabel, style: Ays.label(18, color: Ays.inkDim)),
          AnimatedBuilder(
            animation: intro,
            builder: (context, _) {
              final shown = (level * Curves.easeOut.transform(intro.value))
                  .round()
                  .clamp(level > 0 ? 1 : 0, level);
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(levelLabel(shown), style: Ays.title(88)),
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                text: isRecord ? newBestLabel : bestLabel,
                color: isRecord ? Ays.warning : Ays.inkDim,
                filled: isRecord,
              ),
              if (streakLabel != null)
                _Chip(text: '🔥 $streakLabel', color: Ays.orange),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color, this.filled = false});

  final String text;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        borderRadius: Ays.radiusSmall,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        text,
        style: Ays.label(15, color: filled ? Ays.bg : color),
      ),
    );
  }
}

/// The stupidly simple instruction that ended the run, and why. This is the
/// joke the screenshot travels on.
class _KilledByCard extends StatelessWidget {
  const _KilledByCard({
    required this.label,
    required this.instruction,
    this.reason,
  });

  final String label;
  final String instruction;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      decoration: BoxDecoration(
        borderRadius: Ays.radius,
        border: Border.all(color: Ays.red.withValues(alpha: 0.55)),
        color: Ays.red.withValues(alpha: 0.08),
      ),
      child: Column(
        children: [
          Text(label, style: Ays.mono(11, color: Ays.red)),
          const SizedBox(height: 6),
          BalancedText(
            '“${instruction.toUpperCase()}”',
            style: Ays.instruction(24),
          ),
          if (reason != null && reason != instruction) ...[
            const SizedBox(height: 6),
            Text(
              reason!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Ays.label(15, color: Ays.inkDim),
            ),
          ],
        ],
      ),
    );
  }
}

