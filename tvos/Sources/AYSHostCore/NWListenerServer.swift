//
//  NWListenerServer.swift
//  AYSHostCore
//
//  The real network entry point for a host: binds a TCP listener and hands
//  every accepted connection to `RoomHost.attachClient` as an `HostTransport`
//  ([[Multiplayer Host (tvOS)]] "Net/"). Advertising is folded in here rather
//  than kept as a fully separate type — `NWListener.Service` is a property of
//  the *same* listener, so a standalone "BonjourAdvertiser" would just be
//  this listener's config in disguise. `BonjourService` below is the pure,
//  testable part of that config (the instance name / type rule).
//
//  Mirrors lib/multiplayer/networking/lan_discovery.dart's client-side
//  contract exactly: service type `_ays-party._tcp`, the room code is the
//  Bonjour *instance name* (e.g. `7F4K._ays-party._tcp.local`), resolved via
//  the listener's own SRV+A records — nothing bespoke to keep in sync beyond
//  that string.
//

import Foundation
import Network

/// The Bonjour identity a room advertises. Pulled out as a small pure value
/// so the naming rule is unit-testable without a real listener, exactly like
/// the Dart side's `matchesRoomCode`.
public struct BonjourService: Equatable {
    public static let serviceType = "_ays-party._tcp"

    public let roomCode: String
    public let displayName: String
    public let playerCount: Int
    public let maxPlayers: Int
    public let state: String

    public init(
        roomCode: String,
        displayName: String = "ARE YOU STUPID?",
        playerCount: Int = 0,
        maxPlayers: Int = 8,
        state: String = "lobby"
    ) {
        self.roomCode = roomCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.playerCount = max(0, min(playerCount, maxPlayers))
        self.maxPlayers = maxPlayers
        self.state = state
    }

    /// The Bonjour instance name a client's PTR lookup must match — see
    /// `matchesRoomCode` in lan_discovery.dart for the reverse direction.
    public var instanceName: String { roomCode }

    /// DNS-SD TXT wire format: one length-prefixed UTF-8 `key=value` field.
    /// Short stable keys also work on Android's NSD implementation.
    public var txtRecord: Data {
        let fields = [
            "max=\(maxPlayers)",
            "name=\(displayName)",
            "players=\(playerCount)",
            "room=\(roomCode)",
            "state=\(state)",
        ]
        var data = Data()
        for field in fields {
            let bytes = Array(field.utf8.prefix(255))
            data.append(UInt8(bytes.count))
            data.append(contentsOf: bytes)
        }
        return data
    }

    var nwService: NWListener.Service {
        NWListener.Service(
            name: instanceName,
            type: Self.serviceType,
            domain: nil,
            txtRecord: txtRecord
        )
    }
}

/// Accepts TCP connections and optionally advertises them over Bonjour.
/// Owns no game state at all — every accepted connection is handed off
/// through `onNewTransport` and this class never looks at it again.
public final class NWListenerServer {
    public var onNewTransport: ((HostTransport) -> Void)?

    private var listener: NWListener?
    private let acceptQueue = DispatchQueue(label: "ays.host.listener")
    private(set) var connectionCounter = 0

    public init() {}

    /// Starts listening on `port` (`.any` picks an unused ephemeral port —
    /// the common case for a real host, since the room code plus Bonjour is
    /// how clients find it, not a fixed port). When `advertising` is given,
    /// the same listener also broadcasts `_ays-party._tcp` with the room
    /// code as instance name. Returns the port actually bound, resolving
    /// only once the listener is `.ready` (or throwing on `.failed`).
    ///
    /// `readyTimeout` guards against a listener that never reports a state
    /// at all: on macOS, a plain (unsigned/ad-hoc) binary asking to accept
    /// inbound connections needs the user to grant the "Local Network" TCC
    /// permission the first time — inside an unattended shell with no one
    /// to click Allow, `.stateUpdateHandler` simply never fires. A real,
    /// properly-signed app only hits that dialog once; see
    /// docs/Architecture/Multiplayer Host (tvOS).md and docs/Meta/Decision
    /// Log.md for why this can't be verified headless.
    @discardableResult
    public func start(
        port: NWEndpoint.Port = .any,
        advertising: BonjourService? = nil,
        readyTimeout: TimeInterval = 5
    ) async throws -> UInt16 {
        let listener = try NWListener(using: .tcp, on: port)
        if let advertising {
            listener.service = advertising.nwService
        }
        self.listener = listener

        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            self.connectionCounter += 1
            let connectionQueue = DispatchQueue(
                label: "ays.host.connection.\(self.connectionCounter)"
            )
            let transport = NWConnectionTransport(connection, queue: connectionQueue)
            self.onNewTransport?(transport)
        }

        do {
            return try await withThrowingTaskGroup(of: UInt16.self) { group in
                group.addTask {
                    try await withCheckedThrowingContinuation { continuation in
                        let resumed = OnceFlag()
                        listener.stateUpdateHandler = { state in
                            switch state {
                            case .ready:
                                guard resumed.tryFire() else { return }
                                guard let boundPort = listener.port?.rawValue else {
                                    continuation.resume(throwing: NWListenerServerError.portNotAssigned)
                                    return
                                }
                                continuation.resume(returning: boundPort)
                            case .failed(let error):
                                guard resumed.tryFire() else { return }
                                continuation.resume(throwing: NWListenerServerError.listenerFailed(error))
                            default:
                                break
                            }
                        }
                        listener.start(queue: self.acceptQueue)
                    }
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(readyTimeout * 1_000_000_000))
                    throw NWListenerServerError.readyTimedOut
                }
                guard let result = try await group.next() else {
                    throw NWListenerServerError.readyTimedOut
                }
                group.cancelAll()
                return result
            }
        } catch {
            listener.cancel()
            self.listener = nil
            throw error
        }
    }

    /// Stops accepting new connections. Already-attached transports are
    /// unaffected — closing those is `RoomHost.close()`'s job.
    public func stop() {
        listener?.cancel()
        listener = nil
    }

    /// Refreshes room metadata without rebinding the TCP port. Browsers see
    /// the same service identity with a new TXT snapshot.
    public func updateAdvertising(_ service: BonjourService) {
        acceptQueue.async { [weak self] in
            self?.listener?.service = service.nwService
        }
    }
}
