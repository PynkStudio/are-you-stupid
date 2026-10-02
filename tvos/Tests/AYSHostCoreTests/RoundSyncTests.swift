//
//  RoundSyncTests.swift
//  AYSHostCoreTests
//
//  Mirrors test/multiplayer/round_sync_test.dart: same seed to every client,
//  countdown READY/GO, action judging, LSS lives/elimination/sole-survivor,
//  Battle base score + the exact speed-bonus split.
//

import AYSHostCore
import AYSProtocol
import XCTest

final class RoundSyncTests: XCTestCase {
    func testBothClientsGetTheSameRoundStartTuple() throws {
        let (host, clients) = makeHarness(playerCount: 2)
        clients.forEach { $0.ready(true) }
        try host.startGame()

        try host.startRound(challengeId: "tap_color", seed: 28374, level: 12)

        for c in clients {
            XCTAssertEqual(c.lastRoundStart?.challengeId, "tap_color")
            XCTAssertEqual(c.lastRoundStart?.seed, 28374)
        }
    }

    func testCountdownSendsReadyThenGo() throws {
        let (host, clients) = makeHarness(playerCount: 2)
        clients.forEach { $0.ready(true) }
        try host.startGame()
        try host.startRound(challengeId: "tap_color", seed: 1, level: 1)

        let countdowns = clients[0].received.compactMap { $0 as? RoundCountdown }
        XCTAssertEqual(countdowns.map(\.state), ["READY", "GO"])
    }

    func testUnknownChallengeIdThrowsInsteadOfCrashing() {
        let judge = FakeChallengeJudge(unknownIds: ["ghost_template"])
        let (host, clients) = makeHarness(playerCount: 2, judge: judge)
        clients.forEach { $0.ready(true) }
        try? host.startGame()

        XCTAssertThrowsError(try host.startRound(challengeId: "ghost_template", seed: 1, level: 1)) { error in
            XCTAssertEqual(error as? RoomHostError, .unknownChallenge("ghost_template"))
        }
    }

    /// `RoomHost` no longer judges a count action itself — it trusts
    /// whatever `correct` the client reported (see the design-change note
    /// on `PlayerAction`), and just echoes it back in the per-seat
    /// `RoundResult`.
    func testCountActionCarriesTheClientReportedVerdict() throws {
        let (host, clients) = makeHarness(playerCount: 2)
        clients.forEach { $0.ready(true) }
        try host.startGame()
        try host.startRound(challengeId: "tap_exactly_n", seed: 1, level: 6)

        let roundId = clients[0].lastRoundStart!.roundId
        clients[0].commitCount(5, roundId: roundId, correct: true)
        clients[1].commitCount(3, roundId: roundId, correct: false)

        XCTAssertEqual(clients[0].lastRoundResult?.correct, true)
        XCTAssertEqual(clients[1].lastRoundResult?.correct, false)
    }

    /// "No downtime" (docs/Gameplay/Game Design Pillars.md): the round
    /// shouldn't make the room wait out the full timer once every alive
    /// player has already answered.
    func testRoundClosesAutomaticallyOnceEveryAliveSeatHasAnswered() throws {
        let (host, clients) = makeHarness(playerCount: 3)
        clients.forEach { $0.ready(true) }
        try host.startGame()
        try host.startRound(challengeId: "tap_exactly_n", seed: 1, level: 6)
        let roundId = clients[0].lastRoundStart!.roundId

        clients[0].commitCount(5, roundId: roundId, correct: true)
        XCTAssertNil(clients[0].received.compactMap { $0 as? RoundResults }.last, "round must stay open until every alive seat has answered")

        clients[1].commitCount(3, roundId: roundId, correct: false)
        XCTAssertNil(clients[0].received.compactMap { $0 as? RoundResults }.last)

        clients[2].commitCount(5, roundId: roundId, correct: true)
        let results = clients[0].received.compactMap { $0 as? RoundResults }.last
        XCTAssertEqual(results?.results.count, 3, "the last answer should have closed the round on its own, with no explicit completeRound() call")
    }

    /// A seat eliminated mid-game (LSS) is a spectator, not a vote the round
    /// waits on — the round should still auto-close once every *alive* seat
    /// has answered, ignoring the eliminated one entirely.
    func testRoundClosesAutomaticallyIgnoringEliminatedSeats() throws {
        let (host, clients) = makeHarness(playerCount: 3, lives: 1)
        clients.forEach { $0.ready(true) }
        try host.startGame(mode: .lastStupidStanding)

        try host.startRound(challengeId: "tap_exactly_n", seed: 1, level: 6)
        var roundId = clients[0].lastRoundStart!.roundId
        // Eliminate client 2 (wrong answer, 1 life) — this also auto-closes
        // the round once the remaining two alive seats have answered.
        clients[0].commitCount(5, roundId: roundId, correct: true)
        clients[1].commitCount(5, roundId: roundId, correct: true)
        clients[2].commitCount(3, roundId: roundId, correct: false)
        XCTAssertEqual(host.aliveCount, 2)

        try host.startRound(challengeId: "tap_exactly_n", seed: 2, level: 6)
        roundId = clients[0].lastRoundStart!.roundId
        clients[0].commitCount(5, roundId: roundId, correct: true)
        // Only one alive seat left to answer — the eliminated seat 2 is
        // never expected to submit anything.
        let resultsBefore = clients[0].received.compactMap { $0 as? RoundResults }.count
        clients[1].commitCount(5, roundId: roundId, correct: true)
        let resultsAfter = clients[0].received.compactMap { $0 as? RoundResults }.count
        XCTAssertEqual(resultsAfter, resultsBefore + 1, "the second alive seat's answer should have closed the round")
    }

    func testTimeoutIsJudgedIncorrectOnCompleteRound() throws {
        let (host, clients) = makeHarness(playerCount: 2)
        clients.forEach { $0.ready(true) }
        try host.startGame()
        try host.startRound(challengeId: "tap_color", seed: 1, level: 1)

        // Nobody answers.
        host.completeRound()

        let results = clients[0].received.compactMap { $0 as? RoundResults }.last
        XCTAssertEqual(results?.results.count, 2)
        XCTAssertTrue(results?.results.allSatisfy { !$0.correct } ?? false)
    }

    func testBattleAwardsBaseScoreAndExactSpeedBonusSplit() throws {
        let (host, clients) = makeHarness(playerCount: 2, speedBonus: true)
        clients.forEach { $0.ready(true) }
        try host.startGame(mode: .stupidBattle)
        try host.startRound(challengeId: "tap_color", seed: 1, level: 1)

        let roundId = clients[0].lastRoundStart!.roundId
        // clients[0] answers first (smaller elapsed via an earlier action)
        // by advancing the clock between the two taps.
        clients[0].tap("correct", roundId: roundId, correct: true)
        clients[1].tap("correct", roundId: roundId, correct: true)
        host.completeRound()

        let scoresFor: (SimClient) -> [PlayerScore] = { $0.received.compactMap { $0 as? PlayerScore } }
        let aScore = scoresFor(clients[0]).last(where: { $0.playerId == clients[0].selfId })?.score
        let bScore = scoresFor(clients[0]).last(where: { $0.playerId == clients[1].selfId })?.score

        // Both actions land at the same elapsed ms (clock never advanced),
        // so ordering falls back to submission order: 100+50, 100+25.
        XCTAssertEqual(aScore, 150)
        XCTAssertEqual(bScore, 125)
    }

    func testLSSDecrementsLivesEliminatesAndDeclaresSoleSurvivor() throws {
        let (host, clients) = makeHarness(playerCount: 2, lives: 1)
        clients.forEach { $0.ready(true) }
        try host.startGame(mode: .lastStupidStanding)
        try host.startRound(challengeId: "tap_color", seed: 1, level: 1)

        let roundId = clients[0].lastRoundStart!.roundId
        clients[0].tap("correct", roundId: roundId, correct: true)
        clients[1].tap("wrong", roundId: roundId, correct: false)
        host.completeRound()

        XCTAssertTrue(clients[0].received.contains { ($0 as? PlayerEliminated)?.playerId == clients[1].selfId })
        XCTAssertEqual(clients[0].lastGameEnd?.winnerId, clients[0].selfId)
        XCTAssertEqual(clients[0].lastGameEnd?.results.count, 2)
    }
}
