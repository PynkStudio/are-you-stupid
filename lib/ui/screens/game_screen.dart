import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../challenges/foldable_challenges.dart';
import '../../challenges/registry.dart';
import '../../core/challenge.dart';
import '../../core/challenge_generator.dart';
import '../../core/difficulty.dart';
import '../../core/foldable.dart';
import '../../core/game_engine.dart';
import '../../core/game_state.dart';
import '../../i18n/app_locale.dart';
import '../../i18n/strings.dart';
import '../../services/app_services.dart';
import '../../services/foldable_bridge.dart';
import '../../ai/apple_ai_service.dart';
import '../../ai/commentary.dart';
import '../../ai/feature_flags.dart';
import '../../ai/foldable_commentary.dart';
import '../../ai/providers.dart';
import '../../ai/solo_commentary.dart';
import '../../ai/telemetry.dart';
import '../theme.dart';
import '../widgets/challenge_renderer.dart';
import '../widgets/flash_overlay.dart';
import '../widgets/foldable_simulator_panel.dart';
import '../widgets/timer_bar.dart';
import 'game_over_view.dart';
import '../widgets/balanced_text.dart';

/// The whole run lives on one screen: no route changes between challenges,
/// no route change on Game Over. Restart is one tap and zero navigation.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final GameEngine _engine;

  /// Unfold Your Brain ([[Foldable Architecture]]): the normalized hardware
  /// layer. On a conventional phone the provider never reports, so the
  /// generator keeps serving exactly the classic templates.
  late final HingeStateProvider _hinge;
  late final FoldableDeviceController _device;
  StreamSubscription<FoldableEvent>? _deviceSub;
  final FoldableRoundTracker _foldTracker = FoldableRoundTracker();
  final Random _asideRng = Random();

  /// Bumped on every hardware event so the simulated display frame repaints.
  final ValueNotifier<int> _deviceTick = ValueNotifier(0);
  int _lastPulse = 0;
  late final Ticker _ticker;
  final TapClaim _claim = TapClaim();

  AppServices? _services;
  TelemetryCollector? _telemetry;
  AdaptiveChallengeProvider? _adaptive;
  AiFeatureFlags? _aiFlags;
  SoloCommentator? _commentator;
  Duration _lastTick = Duration.zero;

  /// AI aside for the current wrong flash (null → plain scripted flash).
  String? _wrongAside;

  /// AI Game Over verdict for the run that just ended, once it arrives.
  String? _aiVerdict;

  /// Bumped on every fail so a verdict for an earlier fail (before a
  /// rewarded continue) can't land on a later Game Over.
  int _verdictToken = 0;
  bool _recorded = false;
  bool _isRecord = false;
  bool _continuedRun = false;

  @override
  void initState() {
    super.initState();
    _hinge = createHingeProvider(simulator: kFoldableSimulatorEnabled);
    _device = FoldableDeviceController(
      hinge: _hinge,
      displayIsSimulated: kFoldableSimulatorEnabled,
    );
    if (kFoldableSimulatorEnabled) {
      _device.setDisplay(DisplayConfiguration.expanded);
    }
    WidgetsBinding.instance.addObserver(this);
    // Loaded once, shared by [AIChallengeProvider]'s internal async init and
    // this screen's own adaptive-difficulty gating below — a single
    // `SharedPreferences` round trip, not two ([[Development Plan]] Phase 5).
    final flagsFuture = AiFeatureFlags.load();
    final aiService = AppleAiMethodChannel();
    flagsFuture.then((flags) {
      if (!mounted) return;
      _aiFlags = flags;
      _commentator = SoloCommentator(
        provider: CommentaryProvider(service: aiService, flags: flags),
      );
      _warmCommentary();
    });

    final adaptive = AdaptiveChallengeProvider(
      inner: FallbackChallengeProvider(
        scripted: ScriptedChallengeProvider(
          generator: ChallengeGenerator(
            templates: soloTemplates(kChallengeTemplates),
            capabilities: () => _device.capabilities,
            deviceState: () => _device.state,
          ),
        ),
        ai: AIChallengeProvider(
          service: aiService,
          loadFlags: () => flagsFuture,
          profileSnapshot: () => _telemetry?.profile,
        ),
      ),
    );
    _adaptive = adaptive;
    _engine = GameEngine(provider: adaptive);
    _engine.deviceState = _device.state;
    _engine.addEventListener(_onGameEvent);
    _engine.addListener(_watchHardwarePulse);
    _deviceSub = _device.events.listen(_onDeviceEvent);
    _ticker = createTicker(_onTick)..start();
  }

  Future<void> _setupTelemetry() async {
    // Phase 3: observe the run and derive the player's adaptive profile
    // ([[Player Telemetry and Adaptive Difficulty]]). Never blocks gameplay:
    // the collector attaches after startRun only when prefs are available.
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _telemetry != null) return;
    final collector = TelemetryCollector(prefs: prefs, engine: _engine);
    await collector.load();
    if (!mounted) {
      collector.detach();
      return;
    }
    _telemetry = collector;
  }

  /// Feeds the latest telemetry profile into [_adaptive] — but only when
  /// `aiAdaptiveDifficultyEnabled` is on (default **off**,
  /// [[Feature Flags]]). Leaving the profile at its cold-start `null`
  /// keeps [AdaptiveChallengeProvider] a neutral passthrough, so this is a
  /// true opt-in: nothing about served challenges changes until a player
  /// (or QA) turns the flag on, even though telemetry itself is always
  /// collected ([[Player Telemetry and Adaptive Difficulty]]).
  void _syncAdaptiveProfile() {
    final adaptive = _adaptive;
    final telemetry = _telemetry;
    if (adaptive == null || telemetry == null) return;
    adaptive.setProfile(
      _aiFlags?.aiAdaptiveDifficultyEnabled ?? false ? telemetry.profile : null,
    );
  }

  /// Keeps one wrong-flash aside ready for the current settings/level.
  /// Fire-and-forget: a no-op when the ring is already full.
  void _warmCommentary() {
    final services = _services;
    if (services == null) return;
    _commentator?.warm(
      locale: services.settings.locale,
      allowSpicy: services.settings.roastsEnabled,
      level: _engine.state.level,
    );
  }

  /// Asks for the Game Over verdict the moment the run fails: the wrong
  /// flash is its latency budget ([[AI Commentary]]).
  void _requestVerdict(
    GameState state, {
    Map<String, Object?> hardware = const {},
  }) {
    final services = _services;
    final commentator = _commentator;
    _aiVerdict = null;
    final token = ++_verdictToken;
    if (services == null || commentator == null) return;
    final best = services.scores.bestLevel;
    commentator
        .verdict(
          locale: services.settings.locale,
          allowSpicy: services.settings.roastsEnabled,
          run: RunSummary(
            level: state.level,
            best: best,
            newBest: state.level > best,
            bestStreak: state.bestFastStreak,
            failedInstruction: state.challenge?.view.instruction,
            failReason: state.flashMessage,
            hardware: hardware,
          ),
        )
        .then((line) {
          if (!mounted || line == null || token != _verdictToken) return;
          setState(() => _aiVerdict = line);
        });
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
      _reportViewport();
      _engine.startRun();
      _setupTelemetry();
    }
  }

  void _onDeviceEvent(FoldableEvent event) {
    _foldTracker.recordEvent(event);
    _engine.handleDeviceEvent(event);
    _deviceTick.value++;
  }

  /// A foldable challenge asks for a light haptic tick by bumping
  /// [DeviceVisual.pulse] (challenges stay pure Dart).
  void _watchHardwarePulse() {
    final pulse = _engine.state.challenge?.view.device?.pulse ?? 0;
    if (pulse > _lastPulse) _services?.haptics.tap();
    _lastPulse = pulse;
  }

  /// The viewport is the only display signal real hardware gives us
  /// (approximated — see [[Foldable Hardware Capabilities]]).
  void _reportViewport() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;
    final view = views.first;
    final size = view.physicalSize / view.devicePixelRatio;
    _device.reportViewport(size.width, size.height);
  }

  @override
  void didChangeMetrics() => _reportViewport();

  void _syncSettings() {
    _engine.spicyRoasts = _services?.settings.roastsEnabled ?? true;
    _engine.locale = _services?.settings.locale ?? _engine.locale;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deviceSub?.cancel();
    _device.dispose();
    _deviceTick.dispose();
    _engine.removeListener(_watchHardwarePulse);
    _services?.settings.removeListener(_syncSettings);
    _telemetry?.detach();
    _telemetry = null;
    _ticker.dispose();
    _engine.removeEventListener(_onGameEvent);
    _engine.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final delta = elapsed - _lastTick;
    _lastTick = elapsed;
    _engine.tick(GameEngine.safeDelta(delta));
  }

  void _onGameEvent(GameEvent event, GameState state) {
    final services = _services;
    if (services == null) return;
    switch (event) {
      case GameEvent.correct:
        _foldTracker.finish(passed: true, elapsed: state.elapsed);
        services.sound.correct();
        services.haptics.correct();
        // One event behind telemetry's own listener (registered later, in
        // `_setupTelemetry`) — negligible against a 50-round rolling window.
        _syncAdaptiveProfile();
      case GameEvent.wrong:
        services.sound.wrong();
        services.haptics.wrong();
        _syncAdaptiveProfile();
        final fold = _foldTracker.finish(passed: false, elapsed: state.elapsed);
        // A hardware joke that fits beats a generic aside; the challenge's
        // own fail line stays the headline either way.
        _wrongAside =
            scriptedAside(fold, services.settings.locale, _asideRng) ??
            _commentator?.takeWrongAside()?.toUpperCase();
        _requestVerdict(
          state,
          hardware: fold.isHardwareRound || fold.physical
              ? fold.toContext()
              : const {},
        );
      case GameEvent.gameOver:
        _recordRun(state);
        _telemetry?.persist();
      case GameEvent.runStarted:
        _foldTracker.resetRun();
        _recorded = false;
        _isRecord = false;
        _continuedRun = false;
      case GameEvent.levelStarted:
        final challenge = state.challenge;
        if (challenge != null) _foldTracker.startRound(challenge);
        _lastPulse = challenge?.view.device?.pulse ?? 0;
        if (state.level > 1) services.sound.levelUp();
        _warmCommentary();
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
    if (_engine.state.phase == GamePhase.playing) _foldTracker.recordTap();
    _engine.handleTap(const TapInfo(targetId: null, elapsed: Duration.zero));
  }

  void _onBackgroundUp() {
    if (_claim.consumeUp()) return;
    _engine.handleTap(
      const TapInfo(targetId: null, elapsed: Duration.zero, kind: TapKind.up),
    );
  }

  void _onTarget(String id, int index, TapKind kind) {
    if (kind == TapKind.down && _engine.state.phase == GamePhase.playing) {
      _foldTracker.recordTap();
    }
    _engine.handleTap(
      TapInfo(targetId: id, index: index, elapsed: Duration.zero, kind: kind),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_engine, _deviceTick]),
        builder: (context, _) {
          final state = _engine.state;
          final locale = _services?.settings.locale ?? _engine.locale;
          return Container(
            decoration: const BoxDecoration(gradient: Ays.pageGradient),
            child: Stack(
              children: [
                _SimulatedDisplay(
                  display: kFoldableSimulatorEnabled
                      ? _device.state.display
                      : DisplayConfiguration.unknown,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) => _onBackgroundDown(),
                    onPointerUp: (_) => _onBackgroundUp(),
                    child: SafeArea(child: _buildBody(state, locale)),
                  ),
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
                    message:
                        state.flashMessage ??
                        Strings.t(locale, 'ui.game.default_wrong'),
                    aside: _wrongAside,
                    onSkip: _engine.skipWrongFlash,
                    skipHint: Strings.t(locale, 'ui.game.tap_to_skip'),
                  ),
                if (state.phase == GamePhase.gameOver)
                  GameOverView(
                    // A fresh card per fail, so a continued run's second
                    // Game Over re-rolls its roast and replays its entrance.
                    key: ValueKey(_verdictToken),
                    level: state.level,
                    best: _services?.scores.bestLevel ?? 0,
                    isRecord: _isRecord,
                    bestStreak: state.bestFastStreak,
                    failedInstruction: state.challenge?.view.instruction,
                    failReason: state.flashMessage,
                    aiVerdict: _aiVerdict,
                    canContinue:
                        !state.continueUsed &&
                        (_services?.ads.isRewardedContinueReady ?? false),
                    onRetry: _retry,
                    onContinue: _continueWithAd,
                    onQuit: _quit,
                  ),
                if (kFoldableSimulatorEnabled &&
                    _hinge is SimulatedHingeProvider)
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: SafeArea(
                      child: FoldableSimulatorPanel(
                        hinge: _hinge,
                        device: _device,
                      ),
                    ),
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
                  Strings.t(locale, 'ui.game.best', {
                    'n': '${_services?.scores.bestLevel ?? 0}',
                  }),
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
        if (state.hostQuip != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text(
              state.hostQuip!,
              textAlign: TextAlign.center,
              style: Ays.mono(11, color: Ays.purple),
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
    return BalancedText(
      Strings.t(locale, 'ui.game.ready'),
      style: Ays.title(64),
      maxLines: 1,
    );
  }
}

/// DEVELOPMENT ONLY: squeezes the game into a cover-display-sized column
/// when the simulator says the compact display is active, so layouts get
/// exercised at both sizes. A pass-through on real devices.
class _SimulatedDisplay extends StatelessWidget {
  const _SimulatedDisplay({required this.display, required this.child});

  final DisplayConfiguration display;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (display != DisplayConfiguration.compact) return child;
    return LayoutBuilder(
      builder: (context, c) => Center(
        child: Container(
          width: c.maxWidth * 0.62,
          decoration: BoxDecoration(
            border: Border.all(color: Ays.warning.withValues(alpha: 0.5)),
          ),
          child: child,
        ),
      ),
    );
  }
}
