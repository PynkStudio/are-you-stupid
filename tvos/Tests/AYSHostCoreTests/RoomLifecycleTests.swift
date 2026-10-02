//
//  RoomLifecycleTests.swift
//  AYSHostCoreTests
//
//  Mirrors test/multiplayer/room_lifecycle_test.dart's scenarios against the
//  Swift RoomHost instead of the Dart PartyHostReference.
//

import AYSHostCore
import AYSProtocol
import XCTest

final class RoomLifecycleTests: XCTestCase {
    func testHelloGetsHostHello() {
        let clock = ManualHostClock(1000)
        let host = RoomHost(
            hostName: "TEST HOST", roomCode: "7F4K", maxPlayers: 4,
            clock: clock, judge: FakeChallengeJudge()
        )
        let (hostSide, clientSide) = InMemoryHostTransport.pair()
        host.attachClient(hostSide)
        let client = SimClient(transport: clientSide)

        client.hello()

        XCTAssertEqual(client.lastHostHello?.hostName, "TEST HOST")
        XCTAssertEqual(client.lastHostHello?.roomCode, "7F4K")
        XCTAssertEqual(client.lastHostHello?.maxPlayers, 4)
    }

    func testProtocolVersionMismatchIsRejected() {
        let clock = ManualHostClock(1000)
        let host = RoomHost(clock: clock, judge: FakeChallengeJudge())
        let (hostSide, clientSide) = InMemoryHostTransport.pair()
        host.attachClient(hostSide)
        let client = SimClient(transport: clientSide)

        client.helloWithProtocolVersion(kProtocolVersion + 1)

        XCTAssertNotNil(client.lastRejected)
        XCTAssertNil(client.lastHostHello)
    }

    func testMalformedInputGetsBadMessageAndConnectionStaysUp() {
        let clock = ManualHostClock(1000)
        let host = RoomHost(clock: clock, judge: FakeChallengeJudge())
        let (hostSide, clientSide) = InMemoryHostTransport.pair()
        host.attachClient(hostSide)
        let client = SimClient(transport: clientSide)

        client.sendRaw("not json at all")
        XCTAssertEqual(client.lastError?.code, "BAD_MESSAGE")

        // The connection is forward-tolerant, not torn down.
        client.hello()
        XCTAssertNotNil(client.lastHostHello)
    }

    func testUnknownTypeIsIgnoredForwardTolerant() {
        let clock = ManualHostClock(1000)
        let host = RoomHost(clock: clock, judge: FakeChallengeJudge())
        let (hostSide, clientSide) = InMemoryHostTransport.pair()
        host.attachClient(hostSide)
        let client = SimClient(transport: clientSide)

        client.sendRaw(#"{"protocolVersion":1,"type":"SOME_FUTURE_MESSAGE","ts":0}"#)
        XCTAssertTrue(client.received.isEmpty)

        client.hello()
        XCTAssertNotNil(client.lastHostHello)
    }

    func testJoinGetsPlayerJoinedWithSelfIdAndRoster() {
        let (host, clients) = makeHarness(playerCount: 1)
        let a = clients[0]
        XCTAssertFalse(a.selfId.isEmpty)
        XCTAssertEqual(a.lastPlayerJoined?.players.count, 1)
        XCTAssertEqual(host.seatCount, 1)
    }

    func testRoomFullAtCapacity() {
        let clock = ManualHostClock(1000)
        let host = RoomHost(maxPlayers: 2, clock: clock, judge: FakeChallengeJudge())

        func attach() -> SimClient {
            let (hostSide, clientSide) = InMemoryHostTransport.pair()
            host.attachClient(hostSide)
            return SimClient(transport: clientSide)
        }

        let a = attach(); a.hello(); a.join(name: "A")
        let b = attach(); b.hello(); b.join(name: "B")
        let c = attach(); c.hello(); c.join(name: "C")

        XCTAssertNotNil(a.lastPlayerJoined)
        XCTAssertNotNil(b.lastPlayerJoined)
        XCTAssertNil(c.lastPlayerJoined)
        XCTAssertEqual(c.lastError?.code, "ROOM_FULL")
    }

    func testLeaveDropsSeatAndBroadcastsPlayerLeave() {
        let (host, clients) = makeHarness(playerCount: 2)
        clients[0].leave()

        XCTAssertEqual(host.seatCount, 1)
        XCTAssertTrue(clients[1].received.contains { $0 is PlayerLeave })
    }

    func testReadyTogglesBroadcastRosterToEveryone() {
        // RoomHost only weak-captures itself in its own connection closures
        // (by design — see attachClient's docs), so the *caller* must keep
        // it alive for the room to keep working. withExtendedLifetime makes
        // that requirement explicit here instead of relying on `host`
        // happening to still be in scope.
        let (host, clients) = makeHarness(playerCount: 2)
        withExtendedLifetime(host) {
            clients[0].ready(true)

            XCTAssertEqual(clients[0].lastRoster.first { $0.playerId == clients[0].selfId }?.ready, true)
            XCTAssertEqual(clients[1].lastRoster.first { $0.playerId == clients[0].selfId }?.ready, true)
        }
    }

    func testStartGameNeedsAtLeastTwoReady() {
        let (host, clients) = makeHarness(playerCount: 2)
        clients[0].ready(true)

        XCTAssertThrowsError(try host.startGame()) { error in
            XCTAssertEqual(error as? RoomHostError, .notEnoughReadyPlayers(1))
        }

        clients[1].ready(true)
        XCTAssertNoThrow(try host.startGame())
        XCTAssertTrue(clients[0].received.contains { $0 is StartGame })
    }
}
