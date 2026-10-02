---
tags: [architecture, localization, i18n]
updated: 2026-10-02
---

# Localization

`lib/i18n/` — pure Dart, no Flutter import, so `core/` and `challenges/` can
use it directly (see [[Architecture Overview]]'s one rule). The app ships in
**English, Italian, French, Spanish, Portuguese and German** with no
`flutter_localizations` / ARB / gen-l10n: a hand-rolled string table, built to
fit the project's "no dependency we don't need" habit (see
[[Getting Started]]).

## Why not `flutter_localizations`

The standard `AppLocalizations.of(context)` pattern needs a `BuildContext`.
Challenges are pure Dart, built once per round by a `ChallengeTemplate.build`
function that never sees a widget tree — see [[Challenge System]]. Threading a
translate *function* through `ChallengeParams` solves that without ever
importing Flutter into `core/` or `challenges/`, so this was built as one
small custom layer instead of bridging Flutter's generated class in.

## The pieces

```
lib/i18n/
├── app_locale.dart        AppLocale enum (en/it/fr/es/pt/de) + fromCode()
├── strings.dart            Strings.t(locale, key, args) + Strings.list(...)
├── strings_en.dart          one flat Map<String,String> per language —
├── strings_it.dart          the SOURCE OF TRUTH for every translatable
├── strings_fr.dart          string in the app: challenge text, UI chrome,
├── strings_es.dart          roasts, viral prompts, share text, word content
├── strings_pt.dart
├── strings_de.dart
└── spell_count_data.dart   per-language letter-count data for `spell_count`
```

`Strings.t(locale, key, {args})` looks a key up, substitutes `{placeholder}`
tokens, and falls back to English then to the raw key — a partially
translated locale never crashes or shows a blank string.

## Wiring into the pure-Dart core

`ChallengeParams` (`lib/core/challenge.dart`) carries the current `AppLocale`
(default `AppLocale.en`, so every existing call site — including every test —
keeps compiling and behaving exactly as before) and exposes:

- `p.tr(key, {args})` — a translated string for the current locale.
- `p.colorLabel(GameColor c)` — the color vocabulary word (`color.red`, ...).
- `p.wordButtonTarget` / `p.wordButtonDecoys` / `p.nothingWords` /
  `p.oddWordIntruders` / `p.oppositePairs` / `p.spellCountLetters` /
  `p.spellCountDigits` — the word-content challenges' gameplay data (below).

`GameColorName.label` (no-arg) still returns the **English** word — it exists
only because `test/challenge_behaviour_test.dart` and
`test/challenge_templates_test.dart` call it directly with no locale in
scope. Anything that needs the *current* language must go through
`ChallengeParams.colorLabel` instead.

`ChallengeGenerator.locale` is a mutable field; `GameEngine.locale` forwards to
it. `GameScreen` syncs it from `SettingsManager.locale` the same way it
already syncs `spicyRoasts` — see [[Services]] and [[Game Engine]].

## The word-content challenges — re-authored, not translated

Five challenges use English *words as gameplay*, not chrome, so translating
them literally would either break the puzzle or (for `spell_count`) produce a
wrong answer key. Each has its own equivalent, hand-written per language:

| Challenge | English content | Where |
|---|---|---|
| `tap_word_button` | 7 decoy button words + the "DON'T TAP" target | `word.tap_word_button.*` |
| `tap_nothing_button` | the NOTHING / SOMETHING / ANYTHING / EVERYTHING quartet (index 0 is always correct) | `word.tap_nothing_button.*` |
| `odd_word_out` | 6 intruder nouns mixed with 3 color words | `word.odd_word_out.intruder.*` |
| `opposite` | 6 antonym pairs, stored as `"A|B"` and split at lookup | `word.opposite.pair.*` |
| `spell_count` | word → letter count (answer) and word → number it names (trap) | `lib/i18n/spell_count_data.dart` |

`spell_count` is the sharp edge: the *letter count of the number word itself*
is language-specific (Italian "QUATTRO" is 7 letters, not 4). Every entry in
`spell_count_data.dart` was counted by hand for its own language — do not
generate it by translating the English word list and keeping the English
counts.

## UI strings

Screens read `services.settings.locale` and call `Strings.t(locale, key)`
directly (no `flutter_localizations` delegate). Any screen whose text must
update the moment the language changes wraps its body in
`AnimatedBuilder(animation: services.settings, ...)` — see `home_screen.dart`
and `settings_screen.dart`.

### iOS system strings

The OS, not the game, renders the permission prompts (ATT, camera, local
network), so they are localized natively: `ios/Runner/<lang>.lproj/
InfoPlist.strings` for all six languages, registered as an
`InfoPlist.strings` variant group in `Runner.xcodeproj`, plus
`CFBundleLocalizations` in `Info.plist` — without that key the App Store
lists the app as English-only. A new language needs a new `.lproj` there too.

## Choosing a language

`SettingsManager.locale` (`ays.locale` in `SharedPreferences`, see
[[State and Persistence]]) resolves to: the saved choice, or — when nothing
was ever chosen — the device's language via `PlatformDispatcher`, falling
back to English if that language isn't one of the six. The Settings screen's
LANGUAGE row includes a "SYSTEM" option that clears the saved choice
(`setLocale(null)`) to go back to following the device.

## Translation quality

The IT/FR/ES translations were written with high confidence. PT and DE are a
solid working translation but have **not** been checked by a native speaker —
flag this before relying on them for a store listing or marketing copy.

## Adding a 7th language

1. Add the enum value + native name in `app_locale.dart`.
2. Copy `strings_en.dart` to `strings_<code>.dart`, translate every value,
   keep every key identical (a mismatched key silently falls back to
   English, it will not fail loudly).
3. Add the four word-content pools and the `spell_count` letter/digit maps
   for the new language in `strings_<code>.dart` / `spell_count_data.dart` —
   see the table above.
4. Register the map in `strings.dart`'s `_tables`.
5. Update the coverage note in [[Testing]] if you add a key-parity test.

## Adding a string to an existing challenge

Every new key goes in **all six** `strings_*.dart` files in the same commit —
see [[Adding a Challenge]]. There is no automated check that the six files
stay in sync; a stray key only shows up as an English fallback in the other
five languages, so a quick `grep -c` diff of the key lists is worth running
before you call a change done.
