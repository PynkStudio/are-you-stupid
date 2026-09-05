# ARE YOU STUPID?

> ONE JOB. DON'T FUCK IT UP.

A one-handed, offline, hyper-casual mobile game for **Android and iOS**, built
with Flutter. You get a stupidly simple instruction. You fail on something
stupid. You immediately try again.

By [PynkStudio](https://github.com/PynkStudio).

## The pitch

Every run is the same three beats, over and over, faster each time:

1. A instruction flashes up — uppercase, under 8 words. `TAP RED.` `DON'T TAP RED.`
2. You answer. Right is a 240 ms green flash into the next challenge. Wrong is
   an 850 ms red flash, a one-line roast explaining exactly what you did wrong,
   and Game Over.
3. `TRY AGAIN` puts you back in under a second.

The target reaction after losing isn't "this game sucks" — it's **"I know
exactly what I did wrong, let me go again."** Every one of the 39 challenge
templates is built to fail that way: fair, explainable in one sentence, never
random.

- 39 micro-challenges, 1–5 seconds each, escalating in trickiness — misleading
  wording, shifting rules, ambiguous instructions, fake buttons, visual noise,
  memory, timing
- A run lasts 20 seconds to 2 minutes; score is just the level you reached
- No account, no internet required to play, no backend, no external assets —
  every visual is generated from shapes, gradients and text; audio is system
  sounds
- Built to be screen-recorded vertically and posted — one tap to share your
  best level

## Running it

```bash
flutter pub get
flutter run
flutter test
flutter analyze
```

See [`docs/Development/Getting Started.md`](docs/Development/Getting%20Started.md)
for the full setup, and [`docs/Development/Release Checklist.md`](docs/Development/Release%20Checklist.md)
before shipping a build.

## Project layout

```
lib/core/         game engine, challenge model, generator, difficulty (pure Dart)
lib/challenges/   the 39 challenge templates + registry
lib/services/     settings, scores, sound, haptics, share, ads
lib/ui/           theme, screens, renderer, widgets
docs/             design and architecture notes (Obsidian vault)
test/             contract, behaviour, engine and widget-flow suites
```

## Documentation

The full design and architecture documentation lives in [`docs/`](docs/) — an
Obsidian vault, browsable as plain Markdown on GitHub too. Start at
[`docs/Home.md`](docs/Home.md):

- [Game Design Pillars](docs/Gameplay/Game%20Design%20Pillars.md) — what the game is and why it works
- [Challenge Catalog](docs/Gameplay/Challenge%20Catalog.md) — all 39 templates
- [Architecture Overview](docs/Architecture/Architecture%20Overview.md) — how the code is organised
- [Adding a Challenge](docs/Development/Adding%20a%20Challenge.md) — the most common contribution

## Status

Playable MVP: full gameplay loop, all 39 challenges, persistence, real AdMob
integration, offline-first by design. See [`docs/Home.md`](docs/Home.md) for
the current build status.
