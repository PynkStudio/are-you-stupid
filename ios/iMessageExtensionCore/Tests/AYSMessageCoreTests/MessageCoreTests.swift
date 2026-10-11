import XCTest
@testable import AYSMessageCore

final class MessageCoreTests: XCTestCase {
    func testCodecRoundTripsMatchUnderMessageLimit() throws {
        var match = MessageMatch(seed: 42)
        match.recordFirst(.init(streak: 4, elapsedMilliseconds: 3_200))
        match.recordSecond(.init(streak: 5, elapsedMilliseconds: 3_000))
        match.advanceRound(with: .init(streak: 2, elapsedMilliseconds: 1_900))
        let url = try MatchCodec.encode(match)
        XCTAssertLessThan(url.absoluteString.count, 5_000)
        XCTAssertEqual(try MatchCodec.decode(url), match)
    }

    func testSameSeedProducesSameThreeRoundSequences() {
        let first = StupidChallengeGenerator(matchSeed: 9)
        let second = StupidChallengeGenerator(matchSeed: 9)
        for round in 0..<3 {
            for streak in 0..<20 {
                XCTAssertEqual(first.challenge(round: round, streak: streak), second.challenge(round: round, streak: streak))
            }
        }
    }

    func testRoundWinnerUsesStreakThenTime() {
        XCTAssertEqual(DuelRound(index: 0, first: .init(streak: 6, elapsedMilliseconds: 9_000), second: .init(streak: 5, elapsedMilliseconds: 2_000)).winner, .first)
        XCTAssertEqual(DuelRound(index: 0, first: .init(streak: 6, elapsedMilliseconds: 5_000), second: .init(streak: 6, elapsedMilliseconds: 4_000)).winner, .second)
        XCTAssertEqual(DuelRound(index: 0, first: .init(streak: 6, elapsedMilliseconds: 4_000), second: .init(streak: 6, elapsedMilliseconds: 4_025)).winner, .tie)
    }

    func testMatchScoreCountsResolvedRoundsOnly() {
        var match = MessageMatch(seed: 1)
        match.recordFirst(.init(streak: 3, elapsedMilliseconds: 2_000))
        match.recordSecond(.init(streak: 2, elapsedMilliseconds: 2_000))
        XCTAssertEqual(match.score.first, 1)
        XCTAssertEqual(match.score.second, 0)
    }
}
