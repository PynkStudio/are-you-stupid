import 'package:flutter/material.dart';

import '../../data/roasts.dart';
import '../../data/viral_prompts.dart';
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
  late final String _roast = Roasts.gameOver(
        allowSpicy: AppServices.of(context).settings.roastsEnabled,
      );
  late final String _viral = ViralPrompts.random();

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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Ays.bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ARE YOU STUPID?',
                textAlign: TextAlign.center,
                style: Ays.mono(13, color: Ays.inkDim),
              ),
              const Spacer(),
              Text(
                _roast,
                textAlign: TextAlign.center,
                style: Ays.title(40).copyWith(color: Ays.red),
              ),
              const SizedBox(height: 28),
              Text(
                'I REACHED',
                textAlign: TextAlign.center,
                style: Ays.label(20, color: Ays.inkDim),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('LEVEL ${widget.level}', style: Ays.title(92)),
              ),
              const SizedBox(height: 14),
              if (widget.isRecord)
                Text(
                  'NEW PERSONAL BEST!',
                  textAlign: TextAlign.center,
                  style: Ays.label(22, color: Ays.warning),
                )
              else
                Text(
                  'BEST: LEVEL ${widget.best}',
                  textAlign: TextAlign.center,
                  style: Ays.label(18, color: Ays.inkDim),
                ),
              const SizedBox(height: 18),
              Text(
                'CAN YOU BEAT ME?',
                textAlign: TextAlign.center,
                style: Ays.label(24),
              ),
              const SizedBox(height: 8),
              Text(
                _viral,
                textAlign: TextAlign.center,
                style: Ays.mono(11, color: Ays.inkDim),
              ),
              const Spacer(),
              AysButton(
                label: 'TRY AGAIN',
                height: 88,
                fontSize: 34,
                onTap: widget.onRetry,
              ),
              if (widget.canContinue) ...[
                const SizedBox(height: 12),
                AysButton(
                  label: 'CONTINUE',
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
                      label: 'SHARE RESULT',
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
                      label: 'HOME',
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
    );
  }
}
