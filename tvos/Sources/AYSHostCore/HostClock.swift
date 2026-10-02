//
//  HostClock.swift
//  AYSHostCore
//
//  Mirrors lib/multiplayer/networking/party_transport.dart's FakePartyClock —
//  RoomHost never calls Date()/DispatchTime directly, so tests can drive time
//  deterministically and the real app can drive it off the wall clock without
//  RoomHost knowing the difference. See docs/Architecture/Multiplayer Host
//  (tvOS).md "Testability story".
//

import Foundation

/// A monotonic millisecond clock `RoomHost` reads `nowMs` from on every
/// message it sends.
public protocol HostClock: AnyObject {
    var nowMs: Int { get }
}

/// Deterministic clock for tests: `nowMs` only moves when `advance(_:)` is
/// called, exactly like the Dart `FakePartyClock`.
public final class ManualHostClock: HostClock {
    public private(set) var nowMs: Int

    public init(_ initial: Int = 0) {
        self.nowMs = initial
    }

    public func advance(_ ms: Int) {
        nowMs += ms
    }
}

/// Real wall-clock time for production use — advance it for real by simply
/// reading `Date()` on every access, no driver loop needed (unlike the Dart
/// dev tool's `Timer.periodic` workaround for its own `FakePartyClock`).
public final class SystemHostClock: HostClock {
    public init() {}

    public var nowMs: Int {
        Int(Date().timeIntervalSince1970 * 1000)
    }
}
