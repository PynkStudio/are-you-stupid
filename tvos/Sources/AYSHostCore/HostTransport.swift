//
//  HostTransport.swift
//  AYSHostCore
//
//  Mirrors lib/multiplayer/networking/party_transport.dart's PartyTransport
//  seam: RoomHost only ever talks to this protocol, never to a socket
//  directly, so it's testable without a network and the real
//  NWConnection-backed transport (Net/) can be swapped in without touching
//  RoomHost. Callback-based rather than Combine/AsyncSequence to keep this
//  target dependency-free.
//

/// A line-based duplex channel between the host and one connected client.
/// The wire format is JSONL exactly as docs/Architecture/Multiplayer
/// Protocol.md defines: one JSON object per UTF-8 line.
public protocol HostTransport: AnyObject {
    /// Set once by whoever attaches this transport; called with each inbound
    /// line as it arrives. `line` never contains a newline.
    var onLine: ((String) -> Void)? { get set }

    /// Set once by whoever attaches this transport; called when the remote
    /// end goes away (mirrors Dart's `inbound` stream completing).
    var onDone: (() -> Void)? { get set }

    /// Sends one complete line. `line` must not contain a newline.
    func send(_ line: String)

    /// Closes this end. Safe to call more than once.
    func close()
}

/// The in-process stand-in for a real socket, used by `AYSHostCoreTests` —
/// the same role `InMemoryPartyTransport` plays in the Dart suites.
public final class InMemoryHostTransport: HostTransport {
    public var onLine: ((String) -> Void)?
    public var onDone: (() -> Void)?

    private weak var peer: InMemoryHostTransport?
    private var closed = false

    private init() {}

    /// Creates a fresh connected pair.
    public static func pair() -> (InMemoryHostTransport, InMemoryHostTransport) {
        let a = InMemoryHostTransport()
        let b = InMemoryHostTransport()
        a.peer = b
        b.peer = a
        return (a, b)
    }

    public func send(_ line: String) {
        guard !closed else { return }
        peer?.deliver(line)
    }

    private func deliver(_ line: String) {
        guard !closed else { return }
        onLine?(line)
    }

    public func close() {
        guard !closed else { return }
        closed = true
        peer?.signalRemoteClosed()
        onDone?()
    }

    private func signalRemoteClosed() {
        guard !closed else { return }
        closed = true
        onDone?()
    }
}
