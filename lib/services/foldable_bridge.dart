import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/foldable.dart';

/// The real-hardware [HingeStateProvider]: iOS 27.1 `UIHingeInteraction`
/// readings from `ios/Runner/Foldable/HingeController.swift`
/// ([[Foldable Architecture]]).
///
/// Starts as [DeviceCapabilities.none] and only upgrades when the hinge
/// actually reports a known status — a phone is treated as foldable because
/// its hinge spoke, never because of a model name. No reading ever arrives
/// on older iOS or on a conventional iPhone, so nothing changes there.
class PlatformHingeProvider implements HingeStateProvider {
  PlatformHingeProvider({EventChannel? channel})
    : _channel = channel ?? const EventChannel('ays/foldable/hinge') {
    _sub = _channel.receiveBroadcastStream().listen(
      _onRaw,
      // No native handler (tests, old builds): stay at "none", silently.
      onError: (Object _) {},
      cancelOnError: false,
    );
  }

  /// What a reporting hinge unlocks. The angle is official but its rate and
  /// precision are system policy (UIHinge.h), so every angle check uses
  /// [FoldThresholds] tolerances. The display configuration has no public
  /// API: it is approximated from the viewport.
  static const foldableCapabilities = DeviceCapabilities({
    DeviceCapability.foldState: CapabilitySupport.official,
    DeviceCapability.hingeAngle: CapabilitySupport.official,
    DeviceCapability.displayConfiguration: CapabilitySupport.approximated,
    DeviceCapability.orientation: CapabilitySupport.official,
  }, source: 'platform');

  final EventChannel _channel;
  late final StreamSubscription<dynamic> _sub;
  final _samples = StreamController<HingeSample>.broadcast(sync: true);
  final _caps = StreamController<DeviceCapabilities>.broadcast(sync: true);
  DeviceCapabilities _capabilities = DeviceCapabilities.none;
  HingeSample? _last;

  @override
  HingeSample? get currentSample => _last;

  @override
  Stream<HingeSample> get samples => _samples.stream;

  @override
  DeviceCapabilities get capabilities => _capabilities;

  @override
  Stream<DeviceCapabilities> get capabilityChanges => _caps.stream;

  void _onRaw(dynamic raw) {
    final sample = parse(raw);
    if (sample == null) return;
    if (sample.status != HingeStatus.unknown && !_capabilities.isFoldable) {
      _capabilities = foldableCapabilities;
      _caps.add(_capabilities);
    }
    _last = sample;
    _samples.add(sample);
  }

  /// Channel payload → [HingeSample]. Public for tests.
  @visibleForTesting
  static HingeSample? parse(dynamic raw) {
    if (raw is! Map) return null;
    if (raw['available'] != true) return HingeSample.unavailable;
    return HingeSample(
      status: HingeNormalizer.statusFromRaw(raw['status']),
      angleDegrees: HingeNormalizer.degreesFromRadians(raw['angle']),
      display: HingeNormalizer.displayFromSizeClass(raw['sizeClass']),
    );
  }

  @override
  Future<void> dispose() async {
    await _sub.cancel();
    await _samples.close();
    await _caps.close();
  }
}

/// The provider for this build/platform: the simulator when explicitly
/// enabled in a debug build, the iOS bridge on iOS, nothing elsewhere.
HingeStateProvider createHingeProvider({required bool simulator}) {
  if (simulator) return SimulatedHingeProvider();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return PlatformHingeProvider();
  }
  return NoHingeProvider();
}

/// `flutter run --dart-define=AYS_FOLD_SIM=true` — debug builds only. The
/// `kDebugMode &&` makes it a compile-time false in profile/release, so the
/// simulator can never reach production ([[Foldable Simulator]]).
const bool kFoldableSimulatorEnabled =
    kDebugMode && bool.fromEnvironment('AYS_FOLD_SIM');
