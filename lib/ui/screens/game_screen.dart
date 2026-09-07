import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../challenges/registry.dart';
import '../../core/challenge.dart';
import '../../core/challenge_generator.dart';
import '../../core/difficulty.dart';
import '../../core/game_engine.dart';
import '../../core/game_state.dart';
import '../../i18n/app_locale.dart';
import '../../i18n/strings.dart';
import '../../services/app_services.dart';
import '../../ai/providers.dart';
import '../theme.dart';
import '../widgets/challenge_renderer.dart';
import '../widgets/flash_overlay.dart';
import '../widgets/timer_bar.dart';
import 'game_over_view.dart';

/// The whole run lives on one screen: no route changes between challenges,
/// no route change on Game Over. Restart is one tap and zero navigation.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final GameEngine _engine;
  late final Ticker _ticker;
  final TapClaim _claim = TapClaim();

  AppServices? _services;
  Duration _lastTick = Duration.zero;
  bool _recorded = false;
  bool _isRecord = false;
  bool _continuedRun = false;

  @override
  void initState() {
    super.initState();
    _engine = GameEngine(
      provider: FallbackChallengeProvider(
        scripted: ScriptedChallengeProvider(
          generator: ChallengeGenerator(templates: kChallengeTemplates),
        ),
      ),
    );
    _engine.addEventListener(_onGameEvent);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services == null) {
      final services = AppServices.of(context);
      _services = services;
      _engine.spicyRoasts = services.settings.roastsEnabled;
      _engine.locale = services.settings.locale;
      services.settings.addListener(_syncSettings);
      _engine.startRun();
    }
  }

  void _syncSettings() {
    _engine.spicyRoasts = _services?.settings.roastsEnabled ?? true;
    _engine.locale = _services?.settings.locale ?? _engine.locale;
  }

  @override
  void dispose() {
    _services?.settings.removeListener(_syncSettings);
    _ticker.dispose();
    _engine.removeEventListener(_onGameEvent);
    _engine.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    var delta = elapsed - _lastTick;
    _lastTick = elapsed;
    // Survive frame hitches / returning from an ad without eating a life.
    if (delta > const Duration(milliseconds: 64)) {
      delta = const Duration(milliseconds: 16);
    }
    _engine.tick(delta);
  }

  void _onGameEvent(GameEvent event, GameState state) {
    final services = _services;
    if (services == null) return;
    switch (event) {
      case GameEvent.correct:
        services.sound.correct();
        services.haptics.correct();
      case GameEvent.wrong:
        services.sound.wrong();
        services.haptics.wrong();
      case GameEvent.gameOver:
        _recordRun(state);
      case GameEvent.runStarted:
        _recorded = false;
        _isRecord = false;
        _continuedRun = false;
      case GameEvent.levelStarted:
      case GameEvent.continued:
        break;
    }
  }

  Future<void> _recordRun(GameState state) async {
    if (_recorded) return;
    _recorded = true;
    final services = _services!;
    final record = await services.scores.recordRun(
      level: state.level,
      fastStreak: state.bestFastStreak,
      countAttempt: !_continuedRun,
    );
    if (!mounted) return;
    setState(() => _isRecord = record);
    if (record) {
      services.sound.record();
      services.haptics.record();
    }
  }

  Future<void> _retry() async {
    final services = _services!;
    services.sound.button();
    services.haptics.tap();
    // Interstitials live strictly between runs. Never during gameplay.
    await services.ads.maybeShowInterstitial(context);
    if (!mounted) return;
    _engine.startRun();
  }

  Future<void> _continueWithAd() async {
    final services = _services!;
    services.sound.button();
    final rewarded = await services.ads.showRewardedContinue(context);
    if (!mounted || !rewarded) return;
    _continuedRun = true;
    _recorded = false;
    _engine.continueRun();
  }

  void _quit() {
    _services?.sound.button();
    Navigator.of(context).pop();
  }

  void _onBackgroundDown() {
    if (_claim.consumeDown()) return;
    _engine.handleTap(
      const TapInfo(targetId: null, elapsed: Duration.zero),
    );
  }

  void _onBackgroundUp() {
    if (_claim.consumeUp()) return;
    _engine.handleTap(
      const TapInfo(
        targetId: null,
        elapsed: Duration.zero,
        kind: TapKind.up,
      ),
    );
  }

  void _onTarget(String id, int index, TapKind kind) {
    _engine.handleTap(
      TapInfo(
        targetId: id,
        index: index,
        elapsed: Duration.zero,
        kind: kind,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _engine,
        builder: (context, _) {
          final state = _engine.state;
          final locale = _services?.settings.locale ?? _engine.locale;
          return Container(
            decoration: const BoxDecoration(gradient: Ays.pageGradient),
            child: Stack(
              children: [
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) => _onBackgroundDown(),
                  onPointerUp: (_) => _onBackgroundUp(),
                  child: SafeArea(child: _buildBody(state, locale)),
                ),
                if (state.phase == GamePhase.correct)
                  FlashOverlay(
                    correct: true,
                    message: Strings.t(locale, 'ui.game.yes'),
                    note: state.successNote,
                  ),
                if (state.phase == GamePhase.wrong)
                  FlashOverlay(
                    correct: false,
                    message: state.flashMessage ??
                        Strings.t(locale, 'ui.game.default_wrong'),
                    onSkip: _engine.skipWrongFlash,
                    skipHint: Strings.t(locale, 'ui.game.tap_to_skip'),
                  ),
                if (state.phase == GamePhase.gameOver)
                  GameOverView(
                    level: state.level,
                    best: _services?.scores.bestLevel ?? 0,
                    isRecord: _isRecord,
                    canContinue: !state.continueUsed &&
                        (_services?.ads.isRewardedContinueReady ?? false),
                    onRetry: _retry,
                    onContinue: _continueWithAd,
                    onQuit: _quit,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(GameState state, AppLocale locale) {
    final challenge = state.challenge;
    if (state.phase == GamePhase.intro || challenge == null) {
      return Center(child: _ReadyText(locale: locale));
    }

    final view = challenge.view;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Strings.t(locale, 'ui.game.level', {'n': '${state.level}'}),
                style: Ays.label(22),
              ),
              if (state.fastStreak >= 3)
                Text('🔥 ${state.fastStreak}', style: Ays.label(18))
              else
                Text(
                  Strings.t(
                    locale,
                    'ui.game.best',
                    {'n': '${_services?.scores.bestLevel ?? 0}'},
                  ),
                  style: Ays.mono(13),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TimerBar(
            progress: state.progress,
            visible: view.showTimer && Difficulty.showTimerBar(state.level),
          ),
        ),
        if (state.paceNote != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              state.paceNote!,
              textAlign: TextAlign.center,
              style: Ays.mono(11, color: Ays.warning),
            ),
          ),
        if (state.viralPrompt != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              state.viralPrompt!,
              textAlign: TextAlign.center,
              style: Ays.mono(11, color: Ays.warning),
            ),
          ),
        Expanded(
          child: ChallengeRenderer(
            view: view,
            claim: _claim,
            onTarget: _onTarget,
          ),
        ),
      ],
    );
  }
}

class _ReadyText extends StatelessWidget {
  const _ReadyText({required this.locale});

  final AppLocale locale;

  @override
  Widget build(BuildContext context) {
    return Text(Strings.t(locale, 'ui.game.ready'), style: Ays.title(64));
  }
}
