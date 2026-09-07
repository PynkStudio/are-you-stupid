import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:are_you_stupid/ai/apple_ai_service.dart';
import 'package:are_you_stupid/i18n/app_locale.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannel channel() => const MethodChannel(kAppleIntelligenceChannel);

  void mock(Future<Object?> Function(MethodCall)? handler) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel(), handler);

  tearDown(() => mock(null));

  group('MockAppleAIService', () {
    test('records payloads and honours scripted results', () async {
      final service = MockAppleAIService();
      service.nextChallengeResult = AppleAiProposalResult.ok(
          {'id': 'ai.aaa11'},
          unitId: 'u-1');

      final result = await service.requestChallenge(
          unitId: 'u-1', locale: AppLocale.en, profile: const {'wins': 3});

      expect(result.ok, isTrue);
      expect(result.proposal!['id'], 'ai.aaa11');
      final payload = service.calls['requestChallenge']!.single;
      expect(payload['unitId'], 'u-1');
      expect(payload['locale'], 'en');
      expect((payload['profile'] as Map)['wins'], 3);
    });

    test('defaults to unavailable unless scripted', () async {
      final service = MockAppleAIService();
      final result = await service.requestChallenge(unitId: 'u-1', locale: AppLocale.en);
      expect(result.ok, isFalse);
      expect(result.error!.code, 'unavailable');
    });

    test('commentary, final round, host, cancel and feedback all log', () async {
      final service = MockAppleAIService();
      service.nextCommentaryResult = AppleAiTextResult.ok('LOL');
      service.nextFinalRoundResult = AppleAiProposalResult.ok({'id': 'ai.bbb22'});
      service.nextMultiplayerHostResult = AppleAiProposalResult.ok({'id': 'ai.ccc33'});

      await service.requestCommentary(
          unitId: 'u', locale: AppLocale.fr, kind: 'failure', context: const {'ms': 1200});
      await service.requestFinalRound(unitId: 'u', locale: AppLocale.en);
      await service.requestMultiplayerHost(unitId: 'u', locale: AppLocale.en);
      await service.cancelUnit('u');
      await service.feedback(sentiment: 'good', issue: 'verb', excerpt: 'TAP X');

      expect(service.calls['requestCommentary']!.single['kind'], 'failure');
      expect(service.calls['requestCommentary']!.single['context'], {'ms': 1200});
      expect(service.calls['requestFinalRound'], hasLength(1));
      expect(service.calls['requestMultiplayerHost'], hasLength(1));
      expect(service.calls['cancelUnit'], hasLength(1));
      expect(service.calls['feedback']!.single['sentiment'], 'good');
      expect(service.calls['feedback']!.single['issue'], 'verb');
    });
  });

  group('AppleAiMethodChannel', () {
    test('available → available', () async {
      mock((call) async => {'state': 'available'});
      final service = AppleAiMethodChannel();
      final a = await service.available();
      expect(a.isAvailable, isTrue);
    });

    test('available → unavailable with reason', () async {
      mock((call) async => {'state': 'unavailable', 'reason': 'modelNotReady'});
      final a = await AppleAiMethodChannel().available();
      expect(a.state, 'unavailable');
      expect(a.reason, 'modelNotReady');
    });

    test('available with no native handler → bridgeUnavailable', () async {
      // No mock installed == MissingPluginException path.
      final a = await AppleAiMethodChannel().available();
      expect(a.state, 'unavailable');
      expect(a.reason, 'bridgeUnavailable');
    });

    test('requestChallenge sends the wire payload and decodes the proposal',
        () async {
      late MethodCall received;
      mock((call) async {
        received = call;
        return {
          'ok': true,
          'proposal': {'id': 'ai.abc12', 'instruction': 'TAP', 'elements': const <Object?>[]},
        };
      });

      final result = await AppleAiMethodChannel().requestChallenge(
          unitId: 'u-7', locale: AppLocale.de, profile: const {'losses': 1});

      expect(received.method, 'requestChallenge');
      expect(received.arguments['unitId'], 'u-7');
      expect(received.arguments['locale'], 'de');
      expect(received.arguments['profile'], {'losses': 1});

      expect(result.ok, isTrue);
      expect(result.proposal!['id'], 'ai.abc12');
    });

    test('ok:false carries the error code and retryable flag', () async {
      mock((call) async => {
            'ok': false,
            'error': {'code': 'rateLimited', 'retryable': true},
          });
      final result = await AppleAiMethodChannel()
          .requestChallenge(unitId: 'u-7', locale: AppLocale.en);
      expect(result.ok, isFalse);
      expect(result.error!.code, 'rateLimited');
      expect(result.error!.retryable, isTrue);
    });

    test('ok:true without a proposal is a decodingFailure', () async {
      mock((call) async => {'ok': true});
      final result = await AppleAiMethodChannel()
          .requestChallenge(unitId: 'u-7', locale: AppLocale.en);
      expect(result.ok, isFalse);
      expect(result.error!.code, 'decodingFailure');
    });

    test('a null response (no bridge) is an unavailable failure', () async {
      mock((call) async => null);
      final result = await AppleAiMethodChannel()
          .requestChallenge(unitId: 'u-7', locale: AppLocale.en);
      expect(result.ok, isFalse);
      expect(result.error!.code, 'unavailable');
    });

    test('a PlatformException becomes an unavailable error result', () async {
      mock((call) async =>
          throw PlatformException(code: 'boom', message: 'nope'));
      final result = await AppleAiMethodChannel()
          .requestCommentary(unitId: 'u', locale: AppLocale.en, kind: 'streak');
      expect(result.ok, isFalse);
      expect(result.error!.code, 'unavailable');
    });

    test('commentary decodes text and rejects empty text', () async {
      mock((call) async => {'ok': true, 'text': 'A ROAST.'});
      final good = await AppleAiMethodChannel().requestCommentary(
          unitId: 'u', locale: AppLocale.en, kind: 'failure', context: const {'ms': 700});
      expect(good.ok, isTrue);
      expect(good.text, 'A ROAST.');

      mock((call) async => {'ok': true, 'text': ''});
      final bad = await AppleAiMethodChannel().requestCommentary(
          unitId: 'u', locale: AppLocale.en, kind: 'failure');
      expect(bad.ok, isFalse);
      expect(bad.error!.code, 'decodingFailure');
    });

    test('cancelUnit and feedback read the bare boolean response', () async {
      mock((call) async {
        expect(call.method, 'cancelUnit');
        return true;
      });
      expect(await AppleAiMethodChannel().cancelUnit('u-1'), isTrue);

      mock((call) async {
        expect(call.method, 'feedback');
        expect(call.arguments['sentiment'], 'bad');
        expect(call.arguments.containsKey('issue'), isFalse);
        return false;
      });
      expect(await AppleAiMethodChannel().feedback(sentiment: 'bad'), isFalse);
    });
  });
}