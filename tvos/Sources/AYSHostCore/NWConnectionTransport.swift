//
//  NWConnectionTransport.swift
//  AYSHostCore
//
//  The real `HostTransport` for production use — mirrors
//  lib/multiplayer/networking/session_socket.dart's SocketPartyTransport
//  exactly: plain TCP, JSONL framing (one UTF-8 line per message, [send]
//  appends the newline, inbound bytes are split on '\n'). `Network.framework`
//  is used instead of BSD sockets because it is the modern, App-sandbox-
//  friendly API on tvOS/macOS and gives Bonjour advertising for free via
//  `NWListener.Service` ([[Multiplayer Host (tvOS)]] "Net/").
//
//  `RoomHost` only ever sees this through the `HostTransport` protocol, same
//  as `InMemoryHostTransport` in tests — this file has no knowledge of rooms,
//  players or the protocol's message types.
//

import Foundation
import Network

/// A lock-guarded "fire once" latch — `NWConnection`/`NWListener` state
/// handlers and timeout work items can legitimately race each other to
/// resume the same continuation, and a plain captured `var` isn't provably
/// safe under Swift 6's strict concurrency checking even though every caller
/// here happens to serialize on one queue. `tryFire()` is the only mutating
/// access, so callers just gate their one-time work on its result.
final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false

    func tryFire() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if fired { return false }
        fired = true
        return true
    }
}

/// Wraps one accepted (or dialed) `NWConnection` as a line-based
/// `HostTransport`. Buffers partial reads across `receive` calls since TCP
/// gives no framing guarantee beyond byte order.
public final class NWConnectionTransport: HostTransport {
    public var onLine: ((String) -> Void)?
    public var onDone: (() -> Void)?

    private let connection: NWConnection
    private let queue: DispatchQueue
    private var inboundBuffer = Data()
    private var closed = false

    /// Wraps an already-created connection (accepted by a listener, or
    /// dialed by a client) and starts it. `queue` is the serial queue every
    /// callback for this connection runs on.
    public init(_ connection: NWConnection, queue: DispatchQueue) {
        self.connection = connection
        self.queue = queue
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.signalDone()
            default:
                break
            }
        }
        connection.start(queue: queue)
        receiveLoop()
    }

    /// Dials `host:port` and resolves once the connection is ready, or throws
    /// if it fails or times out. Mirrors `SocketPartyTransport.connect`.
    public static func connect(
        host: String,
        port: UInt16,
        timeout: TimeInterval = 5
    ) async throws -> NWConnectionTransport {
        let queue = DispatchQueue(label: "ays.transport.client")
        let params = NWParameters.tcp
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port) ?? .any,
            using: params
        )

        return try await withCheckedThrowingContinuation { continuation in
            let resumed = OnceFlag()
            let timeoutWork = DispatchWorkItem {
                guard resumed.tryFire() else { return }
                connection.cancel()
                continuation.resume(throwing: NWListenerServerError.connectTimedOut)
            }
            queue.asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard resumed.tryFire() else { return }
                    timeoutWork.cancel()
                    continuation.resume(returning: NWConnectionTransport(connection, queue: queue))
                case .failed(let error):
                    guard resumed.tryFire() else { return }
                    timeoutWork.cancel()
                    connection.cancel()
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    public func send(_ line: String) {
        guard !closed else { return }
        var data = Data(line.utf8)
        data.append(0x0A) // '\n'
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    public func close() {
        guard !closed else { return }
        closed = true
        connection.cancel()
    }

    private func receiveLoop() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.consume(data)
            }
            if isComplete || error != nil {
                self.signalDone()
                return
            }
            self.receiveLoop()
        }
    }

    private func consume(_ chunk: Data) {
        inboundBuffer.append(chunk)
        while let newlineIndex = inboundBuffer.firstIndex(of: 0x0A) {
            let lineData = inboundBuffer[inboundBuffer.startIndex..<newlineIndex]
            inboundBuffer.removeSubrange(inboundBuffer.startIndex...newlineIndex)
            // Mirrors the Dart side's `allowMalformed: true` UTF-8 decoder:
            // never crash the connection over a bad byte sequence.
            let line = String(decoding: lineData, as: UTF8.self)
            onLine?(line)
        }
    }

    private func signalDone() {
        guard !closed else { return }
        closed = true
        onDone?()
    }
}

public enum NWListenerServerError: Error, CustomStringConvertible {
    case connectTimedOut
    case listenerFailed(NWError)
    case portNotAssigned
    case readyTimedOut

    public var description: String {
        switch self {
        case .connectTimedOut: return "connect timed out"
        case .listenerFailed(let error): return "listener failed: \(error)"
        case .portNotAssigned: return "listener never reported an assigned port"
        case .readyTimedOut: return "listener never became ready (likely missing Local Network permission)"
        }
    }
}
