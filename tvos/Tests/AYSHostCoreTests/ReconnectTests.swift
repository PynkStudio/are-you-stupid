//
//  ReconnectTests.swift
//  AYSHostCoreTests
//
//  Mirrors test/multiplayer/reconnect_test.dart: grace-window hold +
//  restore, expiry prune, outside-window reject, and duplicate/stale/
//  closed-round PLAYER_ACTION validation.
//

import AYSHostCore
import AYSProtocol
import XCTest

final class ReconnectTests: XCTestCase {
    func testDisconnectDuringGameHoldsTheSeatAndReconnectRestoresIt() throws {
        let clock = ManualHostClock(1000)
        let (host, clients) = makeHarness(playerCount: 2, clock: clock, graceWindowMs: 15000)
        clients.forEach { $0.ready(true) }
        try host.startGame()
        let originalId = clients[0].selfId

        clients[0].disconnect()
        XCTAssertTrue(clients[1].received.contains { ($0 as? PlayerDisconnected)?.playerId == originalId })
        XCTAssertEqual(host.seatCount, 2, "the seat is held, not dropped, during the grace window")

        clock.advance(5000) // inside the 15s window

        let (hostSide, clientSide) = InMemoryHostTransport.pair()
        host.attachClient(hostSide)
        let rejoined = SimClient(transport: clientSide)
        rejoined.hello()
        rejoined.join(name: "Player0", emoji: "🟢") // same identity as clients[0]

        XCTAssertEqual(rejoined.lastPlayerJoined?.selfClientId, originalId)
        XCTAssertTrue(clients[1].received.contains { ($0 as? PlayerReconnected)?.playerId == originalId })
    }

    func testGraceWindowExpiryPrunesTheDisconnectedPlayer() throws {
        let clock = ManualHostClock(1000)
        let (host, clients) = makeHarness(playerCount: 2, clock: clock, graceWindowMs: 15000)
        clients.forEach { $0.ready(true) }
        try host.startGame()

        clients[0].disconnect()
        clock.advance(15001)
        try host.startRound(challengeId: "tap_color", seed: 1, level: 1) // triggers pruneDisconnected()

        XCTAssertEqual(host.seatCount, 1)
    }

    func testReconnectOutsideTheGraceWindowIsRejected() throws {
        let clock = ManualHostClock(1000)
        let (host, clients) = makeHarness(playerCount: 2, clock: clock, graceWindowMs: 15000)
        clients.forEach { $0.ready(true) }
        try host.startGame()

        clients[0].disconnect()
        clock.advance(15001)

        let (hostSide, clientSide) = InMemoryHostTransport.pair()
        host.attachClient(hostSide)
        let rejoined = SimClient(transport: clientSide)
        rejoined.hello()
        rejoined.join(name: "Player0", emoji: "🟢")

        XCTAssertNil(rejoined.lastPlayerJoined)
        XCTAssertEqual(rejoined.lastError?.code, "ROOM_FULL")
    }

    func testDuplicateActionInTheSameRoundIsRejected() throws {
        let (host, clients) = makeHarness(playerCount: 2)
        clients.forEach { $0.ready(true) }
        try host.startGame()
        try host.startRound(challengeId: "tap_color", seed: 1, level: 1)
        let roundId = clients[0].lastRoundStart!.roundId

        clients[0].tap("correct", roundId: roundId, correct: true)
        clients[0].tap("correct", roundId: roundId, correct: true)

        XCTAssertEqual(clients[0].lastError?.code, "DUPLICATE_ACTION")
    }

    func testActionBeforeAnyRoundIsOpenIsRoundClosed() throws {
        let (host, clients) = makeHarness(playerCount: 2)
        clients.forEach { $0.ready(true) }
        try host.startGame()

        clients[0].tap("correct", roundId: "r-does-not-exist", correct: true)

        XCTAssertEqual(clients[0].lastError?.code, "ROUND_CLOSED")
    }

    func testActionForAStaleRoundIdIsRoundClosed() throws {
        let (host, clients) = makeHarness(playerCount: 2)
        clients.forEach { $0.ready(true) }
        try host.startGame()
        try host.startRound(challengeId: "tap_color", seed: 1, level: 1)

        clients[0].tap("correct", roundId: "some-other-round", correct: true)

        XCTAssertEqual(clients[0].lastError?.code, "ROUND_CLOSED")
    }
}
