---
tags: [architecture, overview]
updated: 2026-09-07
---

# Architecture Overview

```
lib/
├── main.dart                 App entry: orientation, edge-to-edge, service boot
├── core/                     Pure game logic. No widgets. Testable headless.
│   ├── challenge.dart        Challenge, ChallengeView, TargetSpec, TapInfo, host
│   ├── challenge_generator.dart
│   ├── difficulty.dart       The whole difficulty curve, one file
│   ├── game_engine.dart      Run lifecycle, phases, scoring signals
│   └── game_state.dart       Snapshot the UI renders
├── challenges/               One file per family + registry.dart
├── ai/                       Dynamic AI director (loader gated; the rest per docs/AI/ and [[Dynamic AI Director]])
│   ├── providers.dart        ChallengeProvider seam + Scripted/Adaptive/Fallback providers  ✅ Phase 1
│   ├── generated_challenge.dart  provenance-wrapped Challenge  ✅ Phase 1
│   ├── ai_feature_flags.dart Tri-state flags + AI Experience Modes
│   ├── challenge_vocabulary.dart  ChallengeMechanic vocabulary + registry  ✅ Phase 2
│   ├── challenge_validator.dart  sealed verdicts  ✅ Phase 2
│   ├── prefetch_cache.dart   Pre-generation loop — never blocks gameplay
│   ├── telemetry.dart        Mistake classifier + PlayerGameplayProfile
│   └── apple_ai_service.dart Darwin bridge client (ays/apple_intelligence)  ✅ Phase 2 (+ MockAppleAIService for tests)
├── data/                     Roast lines, viral prompts (per-language)
├── i18n/                     Pure Dart string tables — see [[Localization]]
├── services/                 Platform-facing side effects
│   ├── ads/                  AdProvider abstraction + MockAdProvider + policy
│   ├── app_services.dart     Injection root (InheritedWidget)
│   ├── haptic_manager.dart
│   ├── score_manager.dart
│   ├── settings_manager.dart
│   ├── share_manager.dart
│   └── sound_manager.dart
└── ui/
    ├── theme.dart            Palette + type scale. Zero assets.
    ├── screens/              home, game, game over layer, settings, stats
    └── widgets/              renderer, target button, timer bar, flash, mock ad
```

Native side: `ios/Runner/AppleAIService/` holds the **only** native AI code —
`AYSChallengeProposal.swift` (the `@Generable` schema + availability rail) and
`AppleAIController.swift` (the `ays/apple_intelligence` MethodChannel,
registered in `AppDelegate.didInitializeImplicitFlutterEngine`). Android is
untouched. The Swift sources are pinned by `tool/swiftc_ai_gate.sh` (Phase 2 —
[[Foundation Models Integration]]).

## The one rule

**`core/` and `challenges/` never import Flutter widgets.**
`core/game_engine.dart` imports `package:flutter/foundation.dart` only for
`ChangeNotifier`. Challenges describe *what* to show; [[Rendering Pipeline]]
decides *how*. `lib/i18n/` is pure Dart too, precisely so `core/` and
`challenges/` can look up translated strings without breaking this rule —
see [[Localization]].

This is what makes every challenge testable without a widget tree — see
[[Testing]].

## Data flow of one round

```
GameEngine._startLevel
  └─ ChallengeProvider.next(context)   → a fresh GeneratedChallenge
       (lib/ai/providers.dart seam, Phase 1 — [[Development Plan]])
GameScreen Ticker (60 fps)
  └─ GameEngine.tick(delta)
       ├─ Challenge.onTick(elapsed, host)     may mutate its own view
       └─ Challenge.onTimeout(host)           when the clock runs out
Player touch
  └─ ChallengeRenderer → GameEngine.handleTap(TapInfo)
       └─ Challenge.onTap(tap, host)
            └─ host.pass() / host.fail()      (the engine *is* the host)
GameEngine
  ├─ phase = correct → 240 ms → next level
  └─ phase = wrong   → 2.85 s (tap to skip) → gameOver
```

With the AI Director active ([[Dynamic AI Director]]), the `ChallengeProvider`
reads a **pre-generation cache** whose candidates were validated by
`lib/ai/challenge_validator.dart`; on any miss it returns a scripted challenge
and never delays the round ([[Pre-generation Cache]]).

## Related

- [[Game Engine]]
- [[Challenge System]]
- [[Services]]
- [[State and Persistence]]
- [[Localization]]
