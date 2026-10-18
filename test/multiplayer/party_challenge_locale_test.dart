// Playtest: phones, Mac and board were all in Italian, yet multiplayer
// challenges came out in English — the phone built every round with the
// default English locale. Scripted rounds now speak the phone's language.
import 'package:are_you_stupid/i18n/app_locale.dart';
import 'package:are_you_stupid/multiplayer/engine/party_state.dart';
import 'package:are_you_stupid/multiplayer/protocol/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const start = RoundStart(
    roundId: 'r1',
    challengeId: 'dont_tap',
    seed: 7,
    startAt: 0,
    durationMs: 3000,
    config: {'level': 2},
  );

  test('scripted rounds are built in the phone language', () {
    final english = buildPartyChallenge(start);
    final italian = buildPartyChallenge(start, locale: AppLocale.it);
    expect(italian.view.instruction, isNot(english.view.instruction));
    expect(italian.duration, english.duration);
  });
}
