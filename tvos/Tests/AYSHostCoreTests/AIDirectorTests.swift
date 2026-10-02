//
//  AIDirectorTests.swift
//  AYSHostCoreTests
//
//  Phase 7 ([[Multiplayer AI Director]]): dispatch plumbing — a phone's
//  AI_CAPABILITIES is remembered. Phase 8 (below): the election itself,
//  the pending-proposal relay through `startNextRound`, and failover when
//  the elected Director leaves.
//

import XCTest
@testable import AYSHostCore
@testable import AYSProtocol

final class AIDirectorTests: XCTestCase {
    func testAiCapabilitiesIsRememberedPerSeat() {
        let (host, clients) = makeHarness(playerCount: 2)
        let a = clients[0]
        let b = clients[1]

        a.sendAiCapabilities(aiAvailable: true, computeRank: 1, batteryPercent: 91)
        b.sendAiCapabilities(aiAvailable: false)

        XCTAssertEqual(host.aiCapabilities(for: a.selfId)?.aiAvailable, true)
        XCTAssertEqual(host.aiCapabilities(for: a.selfId)?.batteryPercent, 91)
        XCTAssertEqual(host.aiCapabilities(for: b.selfId)?.aiAvailable, false)
    }

    func testASeatThatNeverAnnouncesHasNoCapabilities() {
        let (host, clients) = makeHarness(playerCount: 1)
        XCTAssertNil(host.aiCapabilities(for: clients[0].selfId))
    }

    func testAiRoundProposalIsAcceptedNotErrored() {
        let (_, clients) = makeHarness(playerCount: 1)
        let a = clients[0]
        a.sendAiRoundProposal(roundId: "r1")
        XCTAssertNil(a.lastError, "a Phase-7-unhandled but known kind must not read as BAD_MESSAGE")
    }

    func testAiCommentaryProposalIsAcceptedNotErrored() {
        let (_, clients) = makeHarness(playerCount: 1)
        let a = clients[0]
        a.sendAiCommentaryProposal(kind: "wrong", roundId: "r1", text: "Barely made it.")
        XCTAssertNil(a.lastError, "a Phase-7-unhandled but known kind must not read as BAD_MESSAGE")
    }

    // MARK: - Phase 8: election

    func testElectionPicksTheHighestComputeRank() throws {
        let (host, clients) = makeHarness(playerCount: 3)
        clients[0].sendAiCapabilities(aiAvailable: true, computeRank: 0)
        clients[1].sendAiCapabilities(aiAvailable: true, computeRank: 1)
        clients[2].sendAiCapabilities(aiAvailable: false)
        clients.forEach { $0.ready(true) }

        try host.startGame()

        XCTAssertEqual(host.currentDirectorPeerId, clients[1].selfId)
        for c in clients {
            XCTAssertEqual(c.lastDirectorAssignment?.directorPeerId, clients[1].selfId)
        }
    }

    func testElectionTieBreaksOnTheSmallerPlayerId() throws {
        let (host, clients) = makeHarness(playerCount: 2)
        clients.forEach { $0.sendAiCapabilities(aiAvailable: true, computeRank: 1) }
        clients.forEach { $0.ready(true) }

        try host.startGame()

        let expected = min(clients[0].selfId, clients[1].selfId)
        XCTAssertEqual(host.currentDirectorPeerId, expected)
    }

    func testNoCapableSeatMeansNoDirector() throws {
        let (host, clients) = makeHarness(playerCount: 2)
        clients.forEach { $0.ready(true) }

        try host.startGame()

        XCTAssertNil(host.currentDirectorPeerId)
        XCTAssertEqual(clients[0].lastDirectorAssignment?.directorPeerId, nil)
    }

    // MARK: - Phase 8: pending-proposal relay

    func testStartNextRoundUsesThePendingAiProposalWhenOneIsReady() throws {
        let (host, clients) = makeHarness(playerCount: 2)
        clients[0].sendAiCapabilities(aiAvailable: true, computeRank: 1)
        clients.forEach { $0.ready(true) }
        try host.startGame()
        XCTAssertEqual(host.currentDirectorPeerId, clients[0].selfId)

        clients[0].sendAiRoundProposal(
            roundId: "ignored-client-side-id",
            proposal: ["id": "ai.abc12", "difficulty": ["timeLimitMs": 2500]]
        )
        try host.startNextRound(level: 1)

        for c in clients {
            XCTAssertEqual(c.lastAiChallengeRound?.durationMs, 2500)
            XCTAssertEqual(c.lastAiChallengeRound?.proposal["id"] as? String, "ai.abc12")
            XCTAssertNil(c.lastRoundStart, "an AI round must not also broadcast ROUND_START")
        }
    }

    func testStartNextRoundFallsBackToScriptedWithNoPendingProposal() throws {
        let (host, clients) = makeHarness(playerCount: 2)
        clients[0].sendAiCapabilities(aiAvailable: true, computeRank: 1)
        clients.forEach { $0.ready(true) }
        try host.startGame()

        try host.startNextRound(level: 1)

        XCTAssertNotNil(clients[0].lastRoundStart, "no proposal arrived — must fall back to scripted")
        XCTAssertNil(clients[0].lastAiChallengeRound)
    }

    func testAPendingProposalIsConsumedOnlyOnce() throws {
        let (host, clients) = makeHarness(playerCount: 2)
        clients[0].sendAiCapabilities(aiAvailable: true, computeRank: 1)
        clients.forEach { $0.ready(true) }
        try host.startGame()

        clients[0].sendAiRoundProposal(roundId: "r1", proposal: ["id": "ai.abc12"])
        try host.startNextRound(level: 1) // consumes the pending proposal
        host.completeRound()
        try host.startNextRound(level: 1) // nothing pending anymore — scripted

        XCTAssertNotNil(clients[0].lastRoundStart, "second round had no new proposal — must be scripted")
    }

    func testANonDirectorsRoundProposalIsIgnored() throws {
        let (host, clients) = makeHarness(playerCount: 3)
        clients[0].sendAiCapabilities(aiAvailable: true, computeRank: 1)
        clients.forEach { $0.ready(true) }
        try host.startGame()
        XCTAssertEqual(host.currentDirectorPeerId, clients[0].selfId)

        clients[2].sendAiRoundProposal(roundId: "r1", proposal: ["id": "ai.impersonated"])
        try host.startNextRound(level: 1)

        XCTAssertNotNil(clients[0].lastRoundStart, "an impersonated proposal must not be served")
        XCTAssertNil(clients[0].lastAiChallengeRound)
    }

    func testANonDirectorsCommentaryProposalIsIgnored() {
        let (_, clients) = makeHarness(playerCount: 3)
        clients[0].sendAiCapabilities(aiAvailable: true, computeRank: 1)
        // No startGame() call needed — election isn't required for this
        // check; the seat simply never became Director without one.
        clients[2].sendAiCommentaryProposal(kind: "wrong", roundId: "r1", text: "impersonated")

        XCTAssertNil(clients[0].lastAiCommentary)
        XCTAssertNil(clients[1].lastAiCommentary)
    }

    func testTheDirectorsCommentaryProposalIsRelayedToEveryone() throws {
        let (host, clients) = makeHarness(playerCount: 2)
        clients[0].sendAiCapabilities(aiAvailable: true, computeRank: 1)
        clients.forEach { $0.ready(true) }
        try host.startGame()

        clients[0].sendAiCommentaryProposal(kind: "elimination", roundId: "r1", text: "Gone, but not forgotten.")

        for c in clients {
            XCTAssertEqual(c.lastAiCommentary?.text, "Gone, but not forgotten.")
        }
    }

    // MARK: - Phase 8: failover

    /// A disconnect alone doesn't re-elect — the seat is only *held* for
    /// `graceWindowMs` in case it reconnects (`RoomHost.pruneDisconnected`),
    /// and that pruning only actually runs again from a handful of entry
    /// points (`startRound`/`startAiRound`/`startNextRound`). Advancing the
    /// clock past the grace window and then asking for a round is what
    /// really removes the seat and fires `reelectIfDirectorLeft` — this is
    /// deliberate (a Director that reconnects in time keeps its assignment
    /// instead of losing and immediately regaining it, see `RoomHost`'s own
    /// doc comment on `reelectIfDirectorLeft`), not a test workaround.
    func testDirectorLeavingTriggersReelectionOnceTheGraceWindowExpires() throws {
        let clock = ManualHostClock(0)
        let (host, clients) = makeHarness(playerCount: 3, clock: clock, graceWindowMs: 1000)
        clients[0].sendAiCapabilities(aiAvailable: true, computeRank: 1)
        clients[1].sendAiCapabilities(aiAvailable: true, computeRank: 0)
        clients.forEach { $0.ready(true) }
        try host.startGame()
        XCTAssertEqual(host.currentDirectorPeerId, clients[0].selfId)

        clients[0].disconnect()
        XCTAssertEqual(host.currentDirectorPeerId, clients[0].selfId, "still held, within the grace window")

        clock.advance(1001)
        try host.startNextRound(level: 1) // re-runs pruneDisconnected()

        XCTAssertEqual(host.currentDirectorPeerId, clients[1].selfId)
        XCTAssertEqual(clients[1].lastDirectorAssignment?.directorPeerId, clients[1].selfId)
    }

    func testDirectorLeavingWithNoOtherCandidateClearsTheAssignment() throws {
        let clock = ManualHostClock(0)
        let (host, clients) = makeHarness(playerCount: 2, clock: clock, graceWindowMs: 1000)
        clients[0].sendAiCapabilities(aiAvailable: true, computeRank: 1)
        clients.forEach { $0.ready(true) }
        try host.startGame()
        XCTAssertEqual(host.currentDirectorPeerId, clients[0].selfId)

        clients[0].disconnect()
        clock.advance(1001)
        try host.startNextRound(level: 1)

        XCTAssertNil(host.currentDirectorPeerId)
        XCTAssertEqual(clients[1].lastDirectorAssignment?.directorPeerId, nil)
    }

    func testASeatThatLeavesBeforeTheGameStartsIsExcludedFromTheElection() throws {
        let (host, clients) = makeHarness(playerCount: 3)
        clients[0].sendAiCapabilities(aiAvailable: true, computeRank: 1)
        clients[1].sendAiCapabilities(aiAvailable: true, computeRank: 0)
        clients[0].leave() // pre-game: removeSeat runs immediately, no grace window
        clients[1].ready(true)
        clients[2].ready(true)

        try host.startGame()

        XCTAssertEqual(host.currentDirectorPeerId, clients[1].selfId)
    }
}
