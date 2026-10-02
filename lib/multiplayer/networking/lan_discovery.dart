/// Client-side LAN discovery for `_ays-party._tcp` ([[Multiplayer Protocol]]).
///
/// Bonjour *advertising* is native Swift/`NWListener` work that ships with
/// the tvOS/macOS host app ([[Multiplayer Host (tvOS)]]) — this file is the
/// browsing half only: given a room code, resolve which host on the LAN is
/// serving it.
///
/// Built on `package:nsd` (`NsdManager` on Android, `NSNetServiceBrowser` on
/// iOS/macOS) rather than a raw-socket mDNS implementation — see
/// [[Decision Log]] for why: the previous approach (`package:multicast_dns`)
/// binds its own UDP socket on port 5353, which on real iOS devices
/// intermittently loses a bind race against the OS's own `mDNSResponder`
/// daemon (`OSError: Address already in use`) and, separately, doesn't
/// reliably route through the OS APIs the "Local Network" permission prompt
/// is actually gated on (`SocketException: No route to host`). `nsd` talks
/// to the platform's own Bonjour/DNS-SD stack instead of competing with it
/// for the port.
library;

import 'dart:async';
import 'dart:convert';

import 'package:nsd/nsd.dart';

/// Mirrors `tvos/Sources/AYSHostCore/NWListenerServer.swift`'s
/// `BonjourService.serviceType` exactly — no `.local` domain suffix here,
/// `nsd`'s `startDiscovery` takes the bare `_type._proto` string.
const kAysPartyServiceType = '_ays-party._tcp';

/// A resolved room, ready to open a [SocketPartyTransport] against.
class PartyHostCandidate {
  const PartyHostCandidate({
    required this.roomCode,
    required this.hostname,
    required this.address,
    required this.port,
    this.displayName = 'ARE YOU STUPID?',
    this.playerCount = 0,
    this.maxPlayers = 8,
    this.state = 'lobby',
  });

  final String roomCode;

  /// The advertised target hostname (informational; [address] is what we
  /// actually connect to).
  final String hostname;
  final String address;
  final int port;
  final String displayName;
  final int playerCount;
  final int maxPlayers;
  final String state;

  bool get canJoin => state == 'lobby' && playerCount < maxPlayers;
}

String? _txtString(Service service, String key) {
  final bytes = service.txt?[key];
  if (bytes == null) return null;
  try {
    return utf8.decode(bytes).trim();
  } catch (_) {
    return null;
  }
}

/// Converts one resolved DNS-SD service into the room card shown on mobile.
/// Old hosts without TXT metadata remain joinable with safe defaults.
PartyHostCandidate? candidateFromService(Service service) {
  final serviceName = service.name?.trim();
  final roomCode = (_txtString(service, 'room') ?? serviceName ?? '')
      .toUpperCase();
  final address = service.addresses?.firstOrNull;
  final port = service.port;
  if (roomCode.isEmpty || address == null || port == null) return null;

  final advertisedName = _txtString(service, 'name');
  final fallbackName = (service.host ?? address.address).replaceFirst(
    RegExp(r'\.local\.?$', caseSensitive: false),
    '',
  );
  return PartyHostCandidate(
    roomCode: roomCode,
    hostname: service.host ?? address.address,
    address: address.address,
    port: port,
    displayName: advertisedName?.isNotEmpty == true
        ? advertisedName!
        : fallbackName,
    playerCount: int.tryParse(_txtString(service, 'players') ?? '') ?? 0,
    maxPlayers: int.tryParse(_txtString(service, 'max') ?? '') ?? 8,
    state: _txtString(service, 'state') ?? 'lobby',
  );
}

/// True when a discovered service's instance name is the one advertising
/// [roomCode] — the room code *is* the Bonjour instance name
/// (`BonjourService.instanceName` on the host side, [[Multiplayer
/// Product]]). Pulled out as a pure function so the matching rule
/// (case-insensitive, whitespace-tolerant) is unit-testable without real
/// mDNS I/O.
bool matchesRoomCode(String? serviceName, String roomCode) {
  if (serviceName == null) return false;
  return serviceName.trim().toUpperCase() == roomCode.trim().toUpperCase();
}

/// Long-lived room browser for the Multiplayer landing screen. It owns the
/// native discovery only while that screen is active and emits sorted room
/// snapshots for found, updated and lost services.
class PartyRoomBrowser {
  final _rooms = <String, PartyHostCandidate>{};
  final _controller = StreamController<List<PartyHostCandidate>>.broadcast();
  Discovery? _discovery;

  Stream<List<PartyHostCandidate>> get rooms => _controller.stream;

  Future<void> start() async {
    if (_discovery != null) return;
    try {
      final discovery = await startDiscovery(
        kAysPartyServiceType,
        ipLookupType: IpLookupType.any,
      );
      _discovery = discovery;
      void listener(Service service, ServiceStatus status) {
        final key = service.name?.trim().toUpperCase();
        if (key == null || key.isEmpty) return;
        if (status == ServiceStatus.lost) {
          _rooms.remove(key);
        } else {
          final candidate = candidateFromService(service);
          if (candidate != null) _rooms[key] = candidate;
        }
        _emit();
      }

      discovery.addServiceListener(listener);
      for (final service in discovery.services) {
        listener(service, ServiceStatus.found);
      }
      _emit();
    } catch (_) {
      _emit();
    }
  }

  Future<void> stop() async {
    final discovery = _discovery;
    _discovery = null;
    _rooms.clear();
    _emit();
    if (discovery != null) await stopDiscovery(discovery);
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }

  void _emit() {
    if (_controller.isClosed) return;
    final snapshot = _rooms.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    _controller.add(List.unmodifiable(snapshot));
  }
}

class LanPartyDiscovery {
  /// Browses the LAN for a host advertising [roomCode] and resolves its
  /// address. Returns null if nothing answers within [timeout] — callers
  /// fall back to `ENTER ROOM CODE` guidance, not a retry loop
  /// ([[Multiplayer Product]]). Never throws: any discovery failure
  /// (missing permission, platform error) is folded into the same null
  /// return rather than left to crash the join flow.
  Future<PartyHostCandidate?> resolveRoomCode(
    String roomCode, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    Discovery? discovery;
    try {
      discovery = await startDiscovery(
        kAysPartyServiceType,
        ipLookupType: IpLookupType.any,
      );

      final completer = Completer<PartyHostCandidate?>();
      void listener(Service service, ServiceStatus status) {
        if (status != ServiceStatus.found) return;
        if (!matchesRoomCode(service.name, roomCode)) return;
        final address = service.addresses?.firstOrNull;
        final port = service.port;
        if (address == null || port == null) return;
        if (!completer.isCompleted) {
          completer.complete(
            PartyHostCandidate(
              roomCode: roomCode.trim().toUpperCase(),
              hostname: service.host ?? address.address,
              address: address.address,
              port: port,
            ),
          );
        }
      }

      discovery.addServiceListener(listener);
      // A service already sitting in `discovery.services` from before the
      // listener was attached (a race between `startDiscovery` resolving
      // and the first result arriving) would otherwise never fire it.
      for (final service in discovery.services) {
        listener(service, ServiceStatus.found);
      }

      return await completer.future.timeout(timeout, onTimeout: () => null);
    } catch (_) {
      return null;
    } finally {
      if (discovery != null) {
        unawaited(stopDiscovery(discovery));
      }
    }
  }
}
