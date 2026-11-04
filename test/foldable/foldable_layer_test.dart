// Hardware abstraction layer: normalization, capability detection, the
// controller's event stream, the simulator and the iOS bridge payloads.
import 'package:are_you_stupid/core/foldable.dart';
import 'package:are_you_stupid/services/foldable_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

FoldableState _s(HingeStatus st, [double? a]) =>
    FoldableState(status: st, angleDegrees: a);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('normalization', () {
    test('UIHinge.Status raw values map one-to-one, junk → unknown', () {
      expect(HingeNormalizer.statusFromRaw(0), HingeStatus.unknown);
      expect(HingeNormalizer.statusFromRaw(1), HingeStatus.closed);
      expect(HingeNormalizer.statusFromRaw(2), HingeStatus.partiallyOpen);
      expect(HingeNormalizer.statusFromRaw(3), HingeStatus.fullyOpen);
      expect(HingeNormalizer.statusFromRaw(9), HingeStatus.unknown);
      expect(HingeNormalizer.statusFromRaw('3'), HingeStatus.unknown);
    });

    test('radians → degrees, clamped to 0..180', () {
      expect(
        HingeNormalizer.degreesFromRadians(3.141592653589793 / 2),
        closeTo(90, 0.001),
      );
      expect(HingeNormalizer.degreesFromRadians(-1), 0);
      expect(HingeNormalizer.degreesFromRadians(10), 180);
      expect(HingeNormalizer.degreesFromRadians(null), isNull);
      expect(HingeNormalizer.degreesFromRadians(double.nan), isNull);
    });

    test('simulator thresholds turn angles into statuses', () {
      const t = FoldThresholds.standard;
      expect(t.statusForAngle(0), HingeStatus.closed);
      expect(t.statusForAngle(90), HingeStatus.partiallyOpen);
      expect(t.statusForAngle(180), HingeStatus.fullyOpen);
    });

    test(
      'diff: opening, closing, angle debounce, open→open is an angle change',
      () {
        List<FoldableEventKind> k(FoldableState a, FoldableState b) =>
            HingeNormalizer.diff(a, b).map((e) => e.kind).toList();
        expect(
          k(_s(HingeStatus.closed, 0), _s(HingeStatus.partiallyOpen, 90)),
          [FoldableEventKind.deviceOpened, FoldableEventKind.hingeAngleChanged],
        );
        expect(k(_s(HingeStatus.fullyOpen, 180), _s(HingeStatus.closed, 0)), [
          FoldableEventKind.deviceClosed,
          FoldableEventKind.hingeAngleChanged,
        ]);
        expect(
          k(
            _s(HingeStatus.partiallyOpen, 90),
            _s(HingeStatus.partiallyOpen, 91),
          ),
          isEmpty,
        );
        expect(k(_s(HingeStatus.partiallyOpen), _s(HingeStatus.fullyOpen)), [
          FoldableEventKind.hingeAngleChanged,
        ]);
        expect(k(_s(HingeStatus.fullyOpen, 180), _s(HingeStatus.unknown)), [
          FoldableEventKind.hingeUnavailable,
        ]);
      },
    );
  });

  group('capabilities', () {
    test('a conventional phone can judge nothing', () {
      for (final c in DeviceCapability.values) {
        expect(DeviceCapabilities.none.canJudge(c), isFalse);
      }
      expect(DeviceCapabilities.none.isFoldable, isFalse);
    });

    test('approximated only counts when explicitly allowed', () {
      const caps = PlatformHingeProvider.foldableCapabilities;
      expect(caps.isFoldable, isTrue);
      expect(caps.canJudge(DeviceCapability.displayConfiguration), isFalse);
      expect(
        caps.canJudge(
          DeviceCapability.displayConfiguration,
          allowApproximated: true,
        ),
        isTrue,
      );
      expect(
        DeviceCapabilities.simulated.canJudge(
          DeviceCapability.displayConfiguration,
        ),
        isTrue,
      );
    });

    test('viewport shape approximates the display configuration', () {
      const d = DisplayConfigurationProvider();
      expect(d.classify(390, 844), DisplayConfiguration.compact);
      expect(d.classify(700, 760), DisplayConfiguration.expanded);
      expect(d.classify(0, 0), DisplayConfiguration.unknown);
      expect(d.orientation(844, 390), FoldOrientation.landscape);
    });
  });

  group('controller', () {
    test('simulated hinge events reach listeners, normalized', () async {
      final sim = SimulatedHingeProvider();
      final c = FoldableDeviceController(hinge: sim, displayIsSimulated: true);
      expect(c.state.status, HingeStatus.fullyOpen); // seeded synchronously
      c.setDisplay(DisplayConfiguration.expanded);
      c.setOrientation(FoldOrientation.portrait);
      final kinds = <FoldableEventKind>[];
      c.events.listen((e) => kinds.add(e.kind));
      sim.setAngle(90);
      sim.close();
      sim.open();
      c.setDisplay(DisplayConfiguration.compact);
      c.setOrientation(FoldOrientation.landscape);
      expect(kinds, [
        FoldableEventKind.hingeAngleChanged,
        FoldableEventKind.deviceClosed,
        FoldableEventKind.hingeAngleChanged,
        FoldableEventKind.deviceOpened,
        FoldableEventKind.hingeAngleChanged,
        FoldableEventKind.displayConfigurationChanged,
        FoldableEventKind.deviceOrientationChanged,
      ]);
      await c.dispose();
    });

    test('no display guesses on a phone without the capability', () async {
      final c = FoldableDeviceController(hinge: NoHingeProvider());
      c.reportViewport(700, 760);
      expect(c.state.display, DisplayConfiguration.unknown);
      expect(c.state.orientation, FoldOrientation.portrait);
      await c.dispose();
    });

    test(
      'repeated display transitions never lose or duplicate state',
      () async {
        final c = FoldableDeviceController(
          hinge: SimulatedHingeProvider(),
          displayIsSimulated: true,
        );
        c.setDisplay(DisplayConfiguration.expanded);
        var switches = 0;
        c.events
            .where(
              (e) => e.kind == FoldableEventKind.displayConfigurationChanged,
            )
            .listen((_) => switches++);
        for (var i = 0; i < 50; i++) {
          c.setDisplay(
            i.isEven
                ? DisplayConfiguration.compact
                : DisplayConfiguration.expanded,
          );
          c.setDisplay(c.state.display); // no-op repeats emit nothing
        }
        expect(switches, 50);
        expect(c.state.display, DisplayConfiguration.expanded);
        expect(c.state.status, HingeStatus.fullyOpen);
        await c.dispose();
      },
    );

    test('a first reading is state, not a player action', () {
      // Seen on the iPhone Duo simulator: the bridge's opening reading used
      // to arrive as deviceClosed.
      final kinds = HingeNormalizer.diff(
        FoldableState.unknown,
        const FoldableState(
          status: HingeStatus.closed,
          angleDegrees: 0,
          display: DisplayConfiguration.compact,
        ),
      ).map((e) => e.kind);
      expect(kinds, [FoldableEventKind.initialState]);
    });

    test('dispose cancels every listener — no leak, no late events', () async {
      final sim = SimulatedHingeProvider();
      final c = FoldableDeviceController(hinge: sim);
      var got = 0;
      c.events.listen((_) => got++);
      await c.dispose();
      expect(c.isDisposed, isTrue);
      expect(() => sim.setAngle(10), throwsStateError); // provider closed too
      c.setDisplay(DisplayConfiguration.compact);
      expect(got, 0);
    });

    test('a platform size class retires the viewport guess', () async {
      const channel = EventChannel('ays/foldable/hinge.sizeclass');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockStreamHandler(
        channel,
        MockStreamHandler.inline(
          onListen: (args, sink) => sink.success({
            'available': true,
            'status': 1,
            'angle': 0.0,
            'sizeClass': 1,
          }),
        ),
      );
      final c = FoldableDeviceController(
        hinge: PlatformHingeProvider(channel: channel),
      );
      await pumpEventQueue();
      // Near-square, which the guess would call expanded.
      c.reportViewport(466, 678);
      expect(c.state.display, DisplayConfiguration.compact);
      await c.dispose();
      messenger.setMockStreamHandler(channel, null);
    });

    test('losing the hinge emits hingeUnavailable', () async {
      final sim = SimulatedHingeProvider();
      final c = FoldableDeviceController(hinge: sim);
      final kinds = <FoldableEventKind>[];
      c.events.listen((e) => kinds.add(e.kind));
      sim.loseHinge();
      expect(kinds, [FoldableEventKind.hingeUnavailable]);
      expect(c.state.status, HingeStatus.unknown);
      await c.dispose();
    });
  });

  group('iOS bridge', () {
    test('payload parsing', () {
      final s = PlatformHingeProvider.parse({
        'available': true,
        'status': 2,
        'angle': 1.5707963,
      });
      expect(s!.status, HingeStatus.partiallyOpen);
      expect(s.angleDegrees, closeTo(90, 0.01));
      expect(
        PlatformHingeProvider.parse({'available': false})!.status,
        HingeStatus.unknown,
      );
      expect(PlatformHingeProvider.parse('junk'), isNull);
      expect(
        PlatformHingeProvider.parse({'available': true, 'status': 3})!.display,
        isNull,
      );
      expect(
        PlatformHingeProvider.parse({
          'available': true,
          'status': 1,
          'sizeClass': 1,
        })!.display,
        DisplayConfiguration.compact,
      );
      expect(
        PlatformHingeProvider.parse({
          'available': true,
          'status': 3,
          'sizeClass': 2,
        })!.display,
        DisplayConfiguration.expanded,
      );
    });

    test(
      'becomes foldable only once the hinge reports a known status',
      () async {
        const channel = EventChannel('ays/foldable/hinge.test');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockStreamHandler(
          channel,
          MockStreamHandler.inline(
            onListen: (args, sink) {
              sink.success({'available': true, 'status': 0, 'angle': 0.0});
              sink.success({'available': true, 'status': 3, 'angle': 3.14159});
            },
          ),
        );
        final p = PlatformHingeProvider(channel: channel);
        expect(p.capabilities.isFoldable, isFalse);
        final c = FoldableDeviceController(hinge: p);
        await pumpEventQueue();
        expect(c.capabilities.isFoldable, isTrue);
        expect(c.state.status, HingeStatus.fullyOpen);
        await c.dispose();
        messenger.setMockStreamHandler(channel, null);
      },
    );

    test('a missing native handler leaves the phone conventional', () async {
      final p = PlatformHingeProvider(
        channel: const EventChannel('ays/foldable/none'),
      );
      await pumpEventQueue();
      expect(p.capabilities, DeviceCapabilities.none);
      await p.dispose();
    });
  });
}
