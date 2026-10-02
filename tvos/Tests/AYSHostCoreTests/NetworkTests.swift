//
//  NetworkTests.swift
//  AYSHostCoreTests
//
//  The Swift-side equivalent of test/multiplayer/session_socket_test.dart
//  and socket_integration_test.dart: real loopback TCP, not
//  InMemoryHostTransport, closing the "Net/ is not started" gap
//  ([[Multiplayer Host (tvOS)]]).
//

import AYSHostCore
import AYSProtocol
import XCTest

final class BonjourServiceTests: XCTestCase {
    func testInstanceNameIsTheUppercasedTrimmedRoomCode() {
        XCTAssertEqual(BonjourService(roomCode: "7f4k").instanceName, "7F4K")
        XCTAssertEqual(BonjourService(roomCode: "  7F4K  ").instanceName, "7F4K")
    }

    func testServiceTypeMatchesTheDocumentedContract() {
        XCTAssertEqual(BonjourService.serviceType, "_ays-party._tcp")
    }
}

/// Every real-socket test in this file is gated behind this env var, checked
/// *before* touching `Network.framework` at all — not just skipped after a
/// timeout. On macOS, a plain (unsigned/ad-hoc) binary asking `NWListener`
/// to accept inbound connections needs the one-time "Local Network" TCC
/// permission; inside an unattended shell with no one to click Allow, the
/// underlying XPC call to the network daemon blocks *synchronously*, which
/// can starve Swift concurrency's whole cooperative thread pool — including
/// unrelated `Task.sleep` timers in sibling tasks. That means
/// `NWListenerServer.start(readyTimeout:)`'s own timeout, while still worth
/// having for a real host that gets a `.failed` response (e.g. the user
/// clicks Don't Allow), cannot be trusted to save an automated run from a
/// full process wedge. See docs/Meta/Decision Log.md.
///
/// Run for real with `AYS_RUN_NETWORK_TESTS=1 swift test` from an
/// interactive Terminal — click Allow on the one-time prompt, then these
/// exercise the actual `Net/` layer end-to-end over loopback.
private func startOrSkip(
    _ server: NWListenerServer,
    advertising: BonjourService? = nil
) async throws -> UInt16 {
    try XCTSkipUnless(
        ProcessInfo.processInfo.environment["AYS_RUN_NETWORK_TESTS"] == "1",
        "Skipped by default — needs a one-time interactive macOS Local "
        + "Network permission grant that would otherwise wedge an "
        + "unattended shell indefinitely. Run with AYS_RUN_NETWORK_TESTS=1 "
        + "from an interactive Terminal to exercise it for real."
    )
    return try await server.start(advertising: advertising)
}

final class NWConnectionTransportTests: XCTestCase {
    func testDeliversLinesSentFromTheOtherEnd() async throws {
        let server = NWListenerServer()
        let received = LineCollector()
        server.onNewTransport = { transport in
            transport.onLine = { line in received.add(line) }
        }
        let port = try await startOrSkip(server)
        defer { server.stop() }

        let client = try await NWConnectionTransport.connect(host: "127.0.0.1", port: port)
        defer { client.close() }

        client.send(#"{"type":"HELLO","protocolVersion":1}"#)
        client.send(#"{"type":"JOIN_ROOM","name":"Alice"}"#)

        try await received.waitForCount(2, timeout: 5)
        XCTAssertEqual(received.lines, [
            #"{"type":"HELLO","protocolVersion":1}"#,
            #"{"type":"JOIN_ROOM","name":"Alice"}"#,
        ])
    }

    func testSplitsAMultiLineChunkAndHandlesPartialWrites() async throws {
        let server = NWListenerServer()
        let received = LineCollector()
        server.onNewTransport = { transport in
            transport.onLine = { line in received.add(line) }
        }
        let port = try await startOrSkip(server)
        defer { server.stop() }

        let client = try await NWConnectionTransport.connect(host: "127.0.0.1", port: port)
        defer { client.close() }

        // Two full lines in one logical write, plus a keep-alive third,
        // exercising the buffer's multi-newline split in one `consume` call.
        client.send("one")
        client.send("two")
        client.send("three")

        try await received.waitForCount(3, timeout: 5)
        XCTAssertEqual(received.lines, ["one", "two", "three"])
    }

    func testOnDoneFiresWhenThePeerCloses() async throws {
        let server = NWListenerServer()
        let doneSignal = DoneSignal()
        server.onNewTransport = { transport in
            transport.onDone = { doneSignal.fire() }
        }
        let port = try await startOrSkip(server)

        let client = try await NWConnectionTransport.connect(host: "127.0.0.1", port: port)
        client.close()

        try await doneSignal.wait(timeout: 5)
        server.stop()
    }

    /// End-to-end: a real `RoomHost` behind a real listener, two real
    /// clients over real loopback sockets — the Swift mirror of
    /// socket_integration_test.dart's "two real socket clients join, ready
    /// up, play a round and reach GAME_END". `lives: 1` so a single wrong
    /// answer eliminates Bob and immediately decides the match.
    func testRoomHostOverRealSocketsRunsARoundToGameEnd() async throws {
        let host = RoomHost(
            hostName: "TEST HOST", roomCode: "7F4K", maxPlayers: 4, lives: 1,
            graceWindowMs: 200, clock: SystemHostClock(),
            judge: FakeChallengeJudge()
        )
        let server = NWListenerServer()
        server.onNewTransport = { transport in host.attachClient(transport) }
        let port = try await startOrSkip(server, advertising: BonjourService(roomCode: "7F4K"))
        defer { server.stop() }

        let aliceTransport = try await NWConnectionTransport.connect(host: "127.0.0.1", port: port)
        let bobTransport = try await NWConnectionTransport.connect(host: "127.0.0.1", port: port)
        let alice = SimClient(transport: aliceTransport)
        let bob = SimClient(transport: bobTransport)

        alice.hello()
        alice.join(name: "Alice")
        bob.hello()
        bob.join(name: "Bob")
        try await waitUntil(timeout: 5) { !alice.lastRoster.isEmpty && !bob.lastRoster.isEmpty }
        alice.ready(true)
        bob.ready(true)

        try host.startGame(mode: .lastStupidStanding)
        try host.startRound(challengeId: "count-me", seed: 1, level: 1)
        try await waitUntil(timeout: 5) { alice.lastRoundStart != nil && bob.lastRoundStart != nil }

        let roundId = try XCTUnwrap(alice.lastRoundStart?.roundId)
        alice.commitCount(3, roundId: roundId, correct: true)
        bob.commitCount(1, roundId: roundId, correct: false)
        try await waitUntil(timeout: 5) { alice.lastRoundResult != nil && bob.lastRoundResult != nil }

        host.completeRound()
        try await waitUntil(timeout: 5) { alice.lastGameEnd != nil && bob.lastGameEnd != nil }

        XCTAssertEqual(alice.lastGameEnd?.winnerId, alice.selfId)
    }
}

/// Polls `condition` every 10ms until it's true or `timeout` elapses, then
/// throws. `NWConnectionTransport` delivers on its own dispatch queue, so
/// tests can't just read a `SimClient`'s decoded state synchronously after
/// sending — this is the async equivalent of the Dart suites' `pumpEventQueue`.
private func waitUntil(
    timeout: TimeInterval,
    _ condition: @escaping () -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() >= deadline { throw TimeoutError() }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}

/// A thread-safe line accumulator: `NWConnectionTransport`'s `onLine`
/// callback fires on its own connection queue, never the test's thread.
private final class LineCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var _lines: [String] = []
    private var continuation: CheckedContinuation<Void, Error>?
    private var target = 0

    var lines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _lines
    }

    func add(_ line: String) {
        lock.lock()
        _lines.append(line)
        let shouldResume = _lines.count >= target
        let cont = shouldResume ? continuation : nil
        if shouldResume { continuation = nil }
        lock.unlock()
        cont?.resume(returning: ())
    }

    func waitForCount(_ count: Int, timeout: TimeInterval) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    self.lock.lock()
                    if self._lines.count >= count {
                        self.lock.unlock()
                        continuation.resume(returning: ())
                        return
                    }
                    self.target = count
                    self.continuation = continuation
                    self.lock.unlock()
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TimeoutError()
            }
            try await group.next()
            group.cancelAll()
        }
    }
}

private final class DoneSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false
    private var continuation: CheckedContinuation<Void, Never>?

    func fire() {
        lock.lock()
        fired = true
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(returning: ())
    }

    func wait(timeout: TimeInterval) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    self.lock.lock()
                    if self.fired {
                        self.lock.unlock()
                        continuation.resume(returning: ())
                        return
                    }
                    self.continuation = continuation
                    self.lock.unlock()
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TimeoutError()
            }
            try await group.next()
            group.cancelAll()
        }
    }
}

private struct TimeoutError: Error {}
