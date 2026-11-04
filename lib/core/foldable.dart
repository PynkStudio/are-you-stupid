/// Foldable hardware layer — the normalized model every foldable challenge
/// talks to ([[Foldable Architecture]]).
///
/// This file is PURE DART on purpose: no Flutter imports. Challenges never
/// see a platform API, a method channel or the simulator — only the
/// normalized [FoldableState] / [FoldableEvent] vocabulary below. Where an
/// event came from (iOS `UIHingeInteraction`, the dev simulator, a test) is
/// invisible to them.
library;

import 'dart:async';

/// Normalized hinge status. Mirrors iOS 27.1 `UIHinge.Status` one-to-one
/// (see [[Foldable Hardware Capabilities]]), so nothing is invented.
enum HingeStatus { unknown, closed, partiallyOpen, fullyOpen }

/// Which screen the game is on, as far as we can tell.
///
/// No public Apple API names the inner vs the cover display, so on real
/// hardware this is *approximated* from the viewport shape
/// ([DisplayConfigurationProvider]); only the simulator reports it exactly.
enum DisplayConfiguration { unknown, compact, expanded }

enum FoldOrientation { unknown, portrait, landscape }

/// A hardware capability a challenge can require.
enum DeviceCapability {
  foldState,
  hingeAngle,
  displayConfiguration,
  orientation,
}

/// How trustworthy a capability is on this device, best first.
enum CapabilitySupport {
  /// Backed by a public, documented OS API on this device.
  official,

  /// Driven by the development simulator. Exact, but not real hardware.
  simulated,

  /// Derived from an indirect signal (e.g. viewport shape). Usable for
  /// cosmetics; a challenge must opt in to judging on it.
  approximated,

  /// Not available.
  unavailable,
}

/// What this device can do right now. Immutable; replaced as a whole.
class DeviceCapabilities {
  const DeviceCapabilities(this.support, {this.source = 'none'});

  /// A conventional phone: nothing foldable. Every existing template still
  /// runs; every hardware template is filtered out.
  static const none = DeviceCapabilities({}, source: 'none');

  /// The dev simulator: everything exact.
  static const simulated = DeviceCapabilities({
    DeviceCapability.foldState: CapabilitySupport.simulated,
    DeviceCapability.hingeAngle: CapabilitySupport.simulated,
    DeviceCapability.displayConfiguration: CapabilitySupport.simulated,
    DeviceCapability.orientation: CapabilitySupport.simulated,
  }, source: 'simulator');

  final Map<DeviceCapability, CapabilitySupport> support;

  /// `none` / `simulator` / `platform` — diagnostics only.
  final String source;

  CapabilitySupport supportFor(DeviceCapability c) =>
      support[c] ?? CapabilitySupport.unavailable;

  /// Whether a challenge may *judge* on [c]. Approximated signals only count
  /// when the challenge explicitly opts in.
  bool canJudge(DeviceCapability c, {bool allowApproximated = false}) =>
      switch (supportFor(c)) {
        CapabilitySupport.official || CapabilitySupport.simulated => true,
        CapabilitySupport.approximated => allowApproximated,
        CapabilitySupport.unavailable => false,
      };

  bool get isFoldable => canJudge(DeviceCapability.foldState);

  @override
  bool operator ==(Object other) =>
      other is DeviceCapabilities &&
      other.source == source &&
      other.support.length == support.length &&
      support.entries.every((e) => other.support[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
    source,
    Object.hashAllUnordered(
      support.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

/// One normalized snapshot of the device.
class FoldableState {
  const FoldableState({
    this.status = HingeStatus.unknown,
    this.angleDegrees,
    this.display = DisplayConfiguration.unknown,
    this.orientation = FoldOrientation.unknown,
  });

  static const unknown = FoldableState();

  final HingeStatus status;

  /// Hinge angle, 0 (closed) .. 180 (flat). Null when not reported.
  final double? angleDegrees;
  final DisplayConfiguration display;
  final FoldOrientation orientation;

  bool get isClosed => status == HingeStatus.closed;
  bool get isOpen =>
      status == HingeStatus.partiallyOpen || status == HingeStatus.fullyOpen;

  FoldableState copyWith({
    HingeStatus? status,
    double? angleDegrees,
    bool clearAngle = false,
    DisplayConfiguration? display,
    FoldOrientation? orientation,
  }) => FoldableState(
    status: status ?? this.status,
    angleDegrees: clearAngle ? null : angleDegrees ?? this.angleDegrees,
    display: display ?? this.display,
    orientation: orientation ?? this.orientation,
  );

  @override
  bool operator ==(Object other) =>
      other is FoldableState &&
      other.status == status &&
      other.angleDegrees == angleDegrees &&
      other.display == display &&
      other.orientation == orientation;

  @override
  int get hashCode => Object.hash(status, angleDegrees, display, orientation);

  @override
  String toString() =>
      'FoldableState(${status.name}, ${angleDegrees?.toStringAsFixed(0)}°, '
      '${display.name}, ${orientation.name})';
}

enum FoldableEventKind {
  /// Synthetic: the state at the start of a round. Never a player action.
  initialState,
  deviceOpened,
  deviceClosed,
  hingeAngleChanged,
  displayConfigurationChanged,
  deviceOrientationChanged,

  /// The hinge stopped reporting (e.g. the view left a hinge-aware
  /// hierarchy). Hardware challenges skip instead of failing.
  hingeUnavailable,
}

class FoldableEvent {
  const FoldableEvent(
    this.kind, {
    required this.previous,
    required this.current,
  });

  final FoldableEventKind kind;
  final FoldableState previous;
  final FoldableState current;

  /// A real physical action by the player (not the round-start snapshot,
  /// not a loss of signal).
  bool get isPlayerAction =>
      kind != FoldableEventKind.initialState &&
      kind != FoldableEventKind.hingeUnavailable;

  @override
  String toString() => 'FoldableEvent(${kind.name}, $current)';
}

/// Every hinge threshold in one place. Configurable on purpose: no challenge
/// may need mechanical precision the hardware/SDK can't promise
/// ([[Unfold Your Brain]] → Safety).
class FoldThresholds {
  const FoldThresholds({
    this.closedBelow = 8,
    this.fullyOpenAbove = 172,
    this.angleChangeEpsilon = 2,
    this.bendTarget = 90,
    this.bendTolerance = 30,
    this.safeTolerance = 14,
    this.safeHold = const Duration(milliseconds: 600),
    this.minPhysicalRound = const Duration(milliseconds: 4500),
    this.maxSafeAngle = 160,
    this.minSafeAngle = 40,
  });

  static const standard = FoldThresholds();

  /// Simulator only: angle → status. Real hardware reports status itself.
  final double closedBelow;
  final double fullyOpenAbove;

  /// Smaller angle deltas don't produce a [FoldableEventKind.hingeAngleChanged]
  /// — debounces sensor jitter.
  final double angleChangeEpsilon;

  /// BEND OVER: the "about 90°" window (only with a real angle).
  final double bendTarget;
  final double bendTolerance;

  /// CRACK THE CODE: how close counts, and for how long.
  final double safeTolerance;
  final Duration safeHold;

  /// Hardware rounds never get shorter than this, at any speed: moving a
  /// hinge calmly takes time, and rushing it is how hinges get hurt.
  final Duration minPhysicalRound;

  /// Safe combinations stay well inside the hinge's range.
  final double minSafeAngle;
  final double maxSafeAngle;

  HingeStatus statusForAngle(double degrees) {
    if (degrees < closedBelow) return HingeStatus.closed;
    if (degrees > fullyOpenAbove) return HingeStatus.fullyOpen;
    return HingeStatus.partiallyOpen;
  }
}

/// Raw platform values → normalized ones. Kept separate so the mapping is
/// testable without a device.
class HingeNormalizer {
  const HingeNormalizer._();

  /// `UIHinge.Status` raw values (UIHinge.h, iOS 27.1): 0 unknown,
  /// 1 closed, 2 partiallyOpen, 3 fullyOpen. Anything else → unknown.
  static HingeStatus statusFromRaw(Object? raw) => switch (raw) {
    1 => HingeStatus.closed,
    2 => HingeStatus.partiallyOpen,
    3 => HingeStatus.fullyOpen,
    _ => HingeStatus.unknown,
  };

  /// `UIHinge.angle` is in radians. Clamped to the 0..180 we reason about.
  static double? degreesFromRadians(Object? raw) {
    if (raw is! num || raw.isNaN) return null;
    final deg = raw * 180 / 3.141592653589793;
    return deg.clamp(0, 180).toDouble();
  }

  /// The events a transition [previous] → [current] produces, in a stable
  /// order. Several can fire at once (closing also changes the angle).
  static List<FoldableEvent> diff(
    FoldableState previous,
    FoldableState current, {
    FoldThresholds thresholds = FoldThresholds.standard,
  }) {
    final events = <FoldableEvent>[];
    void add(FoldableEventKind k) =>
        events.add(FoldableEvent(k, previous: previous, current: current));

    final wasOpen = previous.isOpen;
    final isOpenNow = current.isOpen;
    if (previous.status != current.status) {
      if (current.status == HingeStatus.unknown &&
          previous.status != HingeStatus.unknown) {
        add(FoldableEventKind.hingeUnavailable);
      } else if (current.isClosed && previous.status != HingeStatus.closed) {
        add(FoldableEventKind.deviceClosed);
      } else if (isOpenNow && !wasOpen) {
        add(FoldableEventKind.deviceOpened);
      }
    }
    final a = previous.angleDegrees;
    final b = current.angleDegrees;
    final angleMoved =
        (a == null) != (b == null) ||
        (a != null &&
            b != null &&
            (a - b).abs() >= thresholds.angleChangeEpsilon);
    // partiallyOpen ↔ fullyOpen is reported as an angle change: the device
    // was already open.
    final openToOpen =
        wasOpen && isOpenNow && previous.status != current.status;
    if ((b != null && angleMoved) || openToOpen) {
      add(FoldableEventKind.hingeAngleChanged);
    }
    if (previous.display != current.display &&
        current.display != DisplayConfiguration.unknown) {
      add(FoldableEventKind.displayConfigurationChanged);
    }
    if (previous.orientation != current.orientation &&
        current.orientation != FoldOrientation.unknown) {
      add(FoldableEventKind.deviceOrientationChanged);
    }
    return events;
  }
}

/// One hinge reading from a [HingeStateProvider]. `null` status = the hinge
/// is (no longer) reporting.
class HingeSample {
  const HingeSample({required this.status, this.angleDegrees});

  static const unavailable = HingeSample(status: HingeStatus.unknown);

  final HingeStatus status;
  final double? angleDegrees;
}

/// Where hinge readings come from: the iOS bridge, the simulator, a test.
abstract class HingeStateProvider {
  /// The latest reading, if any, applied synchronously when a controller
  /// attaches.
  HingeSample? get currentSample;

  /// Subsequent readings.
  Stream<HingeSample> get samples;

  /// What this provider can deliver, learned so far. May upgrade once the
  /// first real reading arrives (a foldable is only known to be one when
  /// its hinge reports).
  DeviceCapabilities get capabilities;

  /// Stream of capability changes.
  Stream<DeviceCapabilities> get capabilityChanges;

  Future<void> dispose();
}

/// A conventional phone, Android, desktop, tests: never reports anything.
class NoHingeProvider implements HingeStateProvider {
  @override
  HingeSample? get currentSample => null;

  @override
  Stream<HingeSample> get samples => const Stream.empty();

  @override
  DeviceCapabilities get capabilities => DeviceCapabilities.none;

  @override
  Stream<DeviceCapabilities> get capabilityChanges => const Stream.empty();

  @override
  Future<void> dispose() async {}
}

/// Viewport shape → [DisplayConfiguration] / [FoldOrientation].
///
/// An *approximation* on real hardware: no public API identifies the cover
/// vs the inner display ([[Foldable Hardware Capabilities]]). A near-square
/// viewport is read as the unfolded inner display, a tall/narrow one as the
/// compact (cover) display. Never used to judge a challenge unless it opts in.
class DisplayConfigurationProvider {
  const DisplayConfigurationProvider({this.expandedMaxAspect = 1.5});

  /// Long side / short side at or below this → expanded.
  final double expandedMaxAspect;

  DisplayConfiguration classify(double width, double height) {
    if (width <= 0 || height <= 0) return DisplayConfiguration.unknown;
    final long = width > height ? width : height;
    final short = width > height ? height : width;
    return long / short <= expandedMaxAspect
        ? DisplayConfiguration.expanded
        : DisplayConfiguration.compact;
  }

  /// `MotionInputProvider` role: orientation from the viewport, which is
  /// what the player actually sees. Square-ish → unchanged/unknown.
  FoldOrientation orientation(double width, double height) {
    if (width <= 0 || height <= 0) return FoldOrientation.unknown;
    return width > height
        ? FoldOrientation.landscape
        : FoldOrientation.portrait;
  }
}

/// Combines a [HingeStateProvider] with viewport reports into one
/// normalized state + event stream. One per game screen; [dispose] cancels
/// every subscription (no leaked listeners across runs).
class FoldableDeviceController {
  FoldableDeviceController({
    required HingeStateProvider hinge,
    this.thresholds = FoldThresholds.standard,
    this.display = const DisplayConfigurationProvider(),
    this.displayIsSimulated = false,
  }) : _hinge = hinge,
       _capabilities = hinge.capabilities {
    final first = hinge.currentSample;
    if (first != null) _onSample(first);
    _subs.add(_hinge.samples.listen(_onSample));
    _subs.add(
      _hinge.capabilityChanges.listen((c) {
        _capabilities = c;
        _capabilityController.add(c);
      }),
    );
  }

  final HingeStateProvider _hinge;
  final FoldThresholds thresholds;
  final DisplayConfigurationProvider display;

  /// The simulator owns the display configuration; viewport reports then
  /// only update orientation.
  final bool displayIsSimulated;

  final List<StreamSubscription<Object?>> _subs = [];
  final _events = StreamController<FoldableEvent>.broadcast(sync: true);
  final _capabilityController = StreamController<DeviceCapabilities>.broadcast(
    sync: true,
  );

  FoldableState _state = FoldableState.unknown;
  DeviceCapabilities _capabilities;
  bool _disposed = false;

  FoldableState get state => _state;
  DeviceCapabilities get capabilities => _capabilities;
  Stream<FoldableEvent> get events => _events.stream;
  Stream<DeviceCapabilities> get capabilityChanges =>
      _capabilityController.stream;
  bool get isDisposed => _disposed;

  void _onSample(HingeSample s) {
    _apply(
      _state.copyWith(
        status: s.status,
        angleDegrees: s.angleDegrees,
        clearAngle: s.angleDegrees == null,
      ),
    );
  }

  /// The UI reports the logical viewport whenever it changes.
  void reportViewport(double width, double height) {
    final orientation = display.orientation(width, height);
    if (displayIsSimulated) {
      _apply(_state.copyWith(orientation: orientation));
      return;
    }
    final config =
        _capabilities.supportFor(DeviceCapability.displayConfiguration) ==
            CapabilitySupport.unavailable
        ? DisplayConfiguration.unknown
        : display.classify(width, height);
    _apply(_state.copyWith(display: config, orientation: orientation));
  }

  /// Simulator / tests: set the display configuration directly.
  void setDisplay(DisplayConfiguration config) =>
      _apply(_state.copyWith(display: config));

  /// Simulator / tests: force an orientation.
  void setOrientation(FoldOrientation o) =>
      _apply(_state.copyWith(orientation: o));

  void _apply(FoldableState next) {
    if (_disposed || next == _state) return;
    final previous = _state;
    _state = next;
    for (final e in HingeNormalizer.diff(
      previous,
      next,
      thresholds: thresholds,
    )) {
      _events.add(e);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _events.close();
    await _capabilityController.close();
    await _hinge.dispose();
  }
}

/// Development-only virtual hinge ([[Foldable Simulator]]). Feeds the same
/// [FoldableDeviceController] the real bridge does, so challenges can't tell
/// the difference. Never constructed in a release build.
class SimulatedHingeProvider implements HingeStateProvider {
  SimulatedHingeProvider({
    this.thresholds = FoldThresholds.standard,
    double initialAngle = 180,
  }) : _angle = initialAngle;

  final FoldThresholds thresholds;
  final _samples = StreamController<HingeSample>.broadcast(sync: true);
  double _angle;
  bool _available = true;

  double get angle => _angle;
  bool get available => _available;
  HingeStatus get status =>
      _available ? thresholds.statusForAngle(_angle) : HingeStatus.unknown;

  @override
  HingeSample? get currentSample => _current;

  @override
  Stream<HingeSample> get samples => _samples.stream;

  HingeSample get _current => _available
      ? HingeSample(status: status, angleDegrees: _angle)
      : HingeSample.unavailable;

  @override
  DeviceCapabilities get capabilities => DeviceCapabilities.simulated;

  @override
  Stream<DeviceCapabilities> get capabilityChanges => const Stream.empty();

  void setAngle(double degrees) {
    _angle = degrees.clamp(0, 180).toDouble();
    _available = true;
    _samples.add(_current);
  }

  void open() => setAngle(180);
  void close() => setAngle(0);

  /// Simulates the hinge dropping out (e.g. leaving a hinge-aware view).
  void loseHinge() {
    _available = false;
    _samples.add(_current);
  }

  void reset() => setAngle(180);

  @override
  Future<void> dispose() => _samples.close();
}
