import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/roasts.dart';
import '../../data/viral_prompts.dart';
import '../../i18n/strings.dart';
import '../../services/app_services.dart';
import '../theme.dart';
import '../widgets/ays_button.dart';

/// Designed to be screenshotted. Big number, one line of context, one call to
/// action — readable at thumbnail size in a 9:16 clip.
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
  });

  final int level;
  final int best;
  final bool isRecord;
  final bool canContinue;
  final VoidCallback onRetry;
  final VoidCallback onContinue;
  final VoidCallback onQuit;

  @override
  State<GameOverView> createState() => _GameOverViewState();
}

class _GameOverViewState extends State<GameOverView> {
  /// Buttons ignore input for a beat after the card appears, so the tail of
  /// a tap-mashing run can't hit TRY AGAIN / CONTINUE / HOME by accident.
  static const _inputLock = Duration(milliseconds: 600);

  bool _armed = false;
  Timer? _armTimer;

  @override
  void initState() {
    super.initState();
    _armTimer = Timer(_inputLock, () {
      if (mounted) setState(() => _armed = true);
    });
  }

  @override
  void dispose() {
    _armTimer?.cancel();
    super.dispose();
  }

  late final String _roast = Roasts.gameOver(
    allowSpicy: AppServices.of(context).settings.roastsEnabled,
    locale: AppServices.of(context).settings.locale,
  );
  late final String _viral = ViralPrompts.random(
    AppServices.of(context).settings.locale,
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

  @override
  Widget build(BuildContext context) {
    final locale = AppServices.of(context).settings.locale;
    String t(String key, [Map<String, String>? args]) =>
        Strings.t(locale, key, args);
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
                Text(
                  t('app.title'),
                  textAlign: TextAlign.center,
                  style: Ays.mono(13, color: Ays.inkDim),
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _roast,
                    textAlign: TextAlign.center,
                    style: Ays.title(40).copyWith(color: Ays.red),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  t('ui.game_over.i_reached'),
                  textAlign: TextAlign.center,
                  style: Ays.label(20, color: Ays.inkDim),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    t('ui.game_over.level', {'n': '${widget.level}'}),
                    style: Ays.title(92),
                  ),
                ),
                const SizedBox(height: 14),
                if (widget.isRecord)
                  Text(
                    t('ui.game_over.new_best'),
                    textAlign: TextAlign.center,
                    style: Ays.label(22, color: Ays.warning),
                  )
                else
                  Text(
                    t('ui.game_over.best', {'n': '${widget.best}'}),
                    textAlign: TextAlign.center,
                    style: Ays.label(18, color: Ays.inkDim),
                  ),
                const SizedBox(height: 18),
                Text(
                  t('ui.game_over.can_you_beat_me'),
                  textAlign: TextAlign.center,
                  style: Ays.label(24),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _viral,
                    textAlign: TextAlign.center,
                    style: Ays.mono(11, color: Ays.inkDim),
                  ),
                ),
                const Spacer(),
                AysButton(
                  label: t('ui.game_over.try_again'),
                  height: 88,
                  fontSize: 34,
                  onTap: widget.onRetry,
                ),
                if (widget.canContinue) ...[
                  const SizedBox(height: 12),
                  AysButton(
                    label: t('ui.game_over.continue_btn'),
                    icon: '▶',
                    height: 62,
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
                        height: 58,
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
                        height: 58,
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
