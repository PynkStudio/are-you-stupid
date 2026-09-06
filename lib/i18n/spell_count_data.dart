/// Per-language data for the `spell_count` challenge ("TAP THE LETTERS IN
/// ..."). The answer (letter count) and the trap (the number the word itself
/// names) are language-specific — translating the English word list would
/// carry over the wrong answer key. Every entry below was counted by hand for
/// its own language. See `docs/Architecture/Localization.md`.
library;

import 'app_locale.dart';

/// word -> number of letters in it (the correct answer).
const Map<AppLocale, Map<String, int>> kSpellCountLetters = {
  AppLocale.en: {
    'ONE': 3,
    'TWO': 3,
    'FOUR': 4,
    'FIVE': 4,
    'SEVEN': 5,
    'EIGHT': 5,
    'THREE': 5,
    'TWELVE': 6,
  },
  AppLocale.it: {
    'UNO': 3,
    'DUE': 3,
    'QUATTRO': 7,
    'CINQUE': 6,
    'SETTE': 5,
    'OTTO': 4,
    'TRE': 3,
    'DODICI': 6,
  },
  AppLocale.fr: {
    'UN': 2,
    'DEUX': 4,
    'QUATRE': 6,
    'CINQ': 4,
    'SEPT': 4,
    'HUIT': 4,
    'TROIS': 5,
    'DOUZE': 5,
  },
  AppLocale.es: {
    'UNO': 3,
    'DOS': 3,
    'CUATRO': 6,
    'CINCO': 5,
    'SIETE': 5,
    'OCHO': 4,
    'TRES': 4,
    'DOCE': 4,
  },
  AppLocale.pt: {
    'UM': 2,
    'DOIS': 4,
    'QUATRO': 6,
    'CINCO': 5,
    'SETE': 4,
    'OITO': 4,
    'TRÊS': 4,
    'DOZE': 4,
  },
  AppLocale.de: {
    'EINS': 4,
    'ZWEI': 4,
    'VIER': 4,
    'FÜNF': 4,
    'SIEBEN': 6,
    'ACHT': 4,
    'DREI': 4,
    'ZWÖLF': 5,
  },
};

/// word -> the number it names (the trap answer).
const Map<AppLocale, Map<String, int>> kSpellCountDigits = {
  AppLocale.en: {
    'ONE': 1,
    'TWO': 2,
    'FOUR': 4,
    'FIVE': 5,
    'SEVEN': 7,
    'EIGHT': 8,
    'THREE': 3,
    'TWELVE': 12,
  },
  AppLocale.it: {
    'UNO': 1,
    'DUE': 2,
    'QUATTRO': 4,
    'CINQUE': 5,
    'SETTE': 7,
    'OTTO': 8,
    'TRE': 3,
    'DODICI': 12,
  },
  AppLocale.fr: {
    'UN': 1,
    'DEUX': 2,
    'QUATRE': 4,
    'CINQ': 5,
    'SEPT': 7,
    'HUIT': 8,
    'TROIS': 3,
    'DOUZE': 12,
  },
  AppLocale.es: {
    'UNO': 1,
    'DOS': 2,
    'CUATRO': 4,
    'CINCO': 5,
    'SIETE': 7,
    'OCHO': 8,
    'TRES': 3,
    'DOCE': 12,
  },
  AppLocale.pt: {
    'UM': 1,
    'DOIS': 2,
    'QUATRO': 4,
    'CINCO': 5,
    'SETE': 7,
    'OITO': 8,
    'TRÊS': 3,
    'DOZE': 12,
  },
  AppLocale.de: {
    'EINS': 1,
    'ZWEI': 2,
    'VIER': 4,
    'FÜNF': 5,
    'SIEBEN': 7,
    'ACHT': 8,
    'DREI': 3,
    'ZWÖLF': 12,
  },
};
