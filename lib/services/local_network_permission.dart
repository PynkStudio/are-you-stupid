import 'package:flutter/services.dart';

/// What the OS currently allows for local-network (Bonjour) access.
enum LocalNetworkStatus { granted, denied, unknown }

/// Local-network permission probe + "open this app's Settings" shortcut,
/// over the `ays/permissions` channel ([[Services]], [[Multiplayer Client
/// (Mobile)]] "Permissions").
///
/// iOS has no API that *reads* the Local Network permission: the native side
/// runs a short `NWBrowser` on `_ays-party._tcp` and reports whether the OS
/// lets it browse. That browse is also what makes iOS show its system prompt
/// the first time, so [status] must only be called after the multiplayer
/// primer has explained why ([MultiplayerProfileManager.permissionsPrimerSeen]).
///
/// Android needs no runtime permission for NSD, so it always answers
/// `granted`. Never throws: a missing channel (tests, desktop) is `unknown`,
/// which the UI treats as "don't nag".
class LocalNetworkPermission {
  const LocalNetworkPermission();

  static const _channel = MethodChannel('ays/permissions');

  Future<LocalNetworkStatus> status() async {
    try {
      final raw = await _channel.invokeMethod<String>('localNetworkStatus');
      return switch (raw) {
        'granted' => LocalNetworkStatus.granted,
        'denied' => LocalNetworkStatus.denied,
        _ => LocalNetworkStatus.unknown,
      };
    } catch (_) {
      return LocalNetworkStatus.unknown;
    }
  }

  /// Opens this app's page in the system Settings app, where the user can
  /// switch Local Network / Camera back on. Returns false if it couldn't.
  Future<bool> openAppSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
    } catch (_) {
      return false;
    }
  }
}
