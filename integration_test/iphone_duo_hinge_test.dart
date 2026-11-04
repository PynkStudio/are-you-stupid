// Runs INSIDE an iPhone Duo simulator or device, against the real
// HingeController.swift — the path test/foldable/ can only mock:
//
//   flutter test integration_test/iphone_duo_hinge_test.dart -d <device>
//
// Pass --dart-define=AYS_WATCH_HINGE_SECONDS=60 to keep listening while you
// fold the device in Device Hub; every reading is printed.
import 'package:are_you_stupid/core/foldable.dart';
import 'package:are_you_stupid/services/foldable_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _watchSeconds = int.fromEnvironment('AYS_WATCH_HINGE_SECONDS');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the native hinge reaches the normalized layer', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.expand()));
    final provider = PlatformHingeProvider();
    final device = FoldableDeviceController(hinge: provider);
    final view = tester.view;
    final size = view.physicalSize / view.devicePixelRatio;
    device.reportViewport(size.width, size.height);
    final sub = device.events.listen((e) => debugPrint('[event] $e'));

    // Real time, not fake-async: the reading comes over a platform channel.
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && !device.capabilities.isFoldable; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await Future<void>.delayed(const Duration(seconds: _watchSeconds));
    });

    debugPrint(
      '[probe] viewport ${size.width}x${size.height} '
      'state ${device.state} source ${device.capabilities.source}',
    );
    expect(device.capabilities.isFoldable, isTrue);
    expect(device.state.status, isNot(HingeStatus.unknown));
    expect(device.state.angleDegrees, isNotNull);
    expect(device.state.display, isNot(DisplayConfiguration.unknown));

    await tester.runAsync(() async {
      await sub.cancel();
      await device.dispose();
    });
  });
}
