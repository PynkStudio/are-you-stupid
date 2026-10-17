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

    func testNoFamilyRepeatsBackToBack() {
        for seed in UInt64(1)...40 {
            let generator = StupidChallengeGenerator(matchSeed: seed)
            for round in 0..<3 {
                var previous: StupidChallenge?
                for streak in 0..<30 {
                    let challenge = generator.challenge(round: round, streak: streak)
                    if let previous {
                        XCTAssertNotEqual(previous.kind, challenge.kind, "seed \(seed) round \(round) streak \(streak)")
                        XCTAssertNotEqual(previous.instruction, challenge.instruction)
                    }
                    previous = challenge
                }
            }
        }
    }

    func testRoundsCoverManyFamilies() {
        let generator = StupidChallengeGenerator(matchSeed: 7)
        for round in 0..<3 {
            let kinds = Set((0..<12).map { generator.challenge(round: round, streak: $0).kind })
            XCTAssertGreaterThanOrEqual(kinds.count, 4, "round \(round)")
        }
    }

    func testOppositeAlwaysNamesItsWordAndAnswersThePartner() {
        for language in MessageLanguage.allCases {
            let pairs = MessageStrings.oppositePairs[language]!
            for seed in UInt64(1)...60 {
                let generator = StupidChallengeGenerator(matchSeed: seed, language: language)
                for streak in 0..<20 {
                    let challenge = generator.challenge(round: 2, streak: streak)
                    guard challenge.kind == .opposite, case .choose(let correct) = challenge.behavior else { continue }
                    let answer = challenge.choices[correct]
                    let other = challenge.choices[1 - correct]
                    XCTAssertTrue(challenge.instruction.hasSuffix(" \(other)"), challenge.instruction)
                    XCTAssertTrue(pairs.contains { ($0.0 == answer && $0.1 == other) || ($0.1 == answer && $0.0 == other) })
                }
            }
        }
    }

    func testSequenceIsIdenticalAcrossLanguages() {
        let english = StupidChallengeGenerator(matchSeed: 99, language: .en)
        for language in MessageLanguage.allCases {
            let local = StupidChallengeGenerator(matchSeed: 99, language: language)
            for round in 0..<3 {
                for streak in 0..<15 {
                    let a = english.challenge(round: round, streak: streak)
                    let b = local.challenge(round: round, streak: streak)
                    XCTAssertEqual(a.kind, b.kind)
                    XCTAssertEqual(a.behavior, b.behavior)
                    XCTAssertEqual(a.durationMilliseconds, b.durationMilliseconds)
                }
            }
        }
    }

    func testEveryLanguageIsCompleteAndInstructionsStayShort() {
        for language in MessageLanguage.allCases {
            for key in MessageStrings.keys {
                XCTAssertTrue(MessageStrings.has(language, key), "\(language) missing \(key)")
            }
            for seed in UInt64(1)...20 {
                let generator = StupidChallengeGenerator(matchSeed: seed, language: language)
                for round in 0..<3 {
                    for streak in 0..<15 {
                        let challenge = generator.challenge(round: round, streak: streak)
                        let words = challenge.instruction.split(separator: " ").count
                        XCTAssertLessThan(words, 8, challenge.instruction)
                        XCTAssertEqual(challenge.instruction, challenge.instruction.uppercased())
                        XCTAssertFalse(challenge.instruction.contains("{"))
                        XCTAssertFalse(challenge.failLine.isEmpty)
                    }
                }
            }
        }
    }

    func testPreferredLanguageFollowsDevice() {
        XCTAssertEqual(MessageLanguage.preferred(["it-IT", "en-US"]), .it)
        XCTAssertEqual(MessageLanguage.preferred(["pt-BR"]), .pt)
        XCTAssertEqual(MessageLanguage.preferred(["ja-JP", "de-DE"]), .de)
        XCTAssertEqual(MessageLanguage.preferred(["zh-Hans"]), .en)
    }

    func testViewerRoleAndPerspectiveScore() {
        XCTAssertTrue(MessageMatch.viewerIsFirst(stage: .awaitingReply, sentByViewer: true))
        XCTAssertFalse(MessageMatch.viewerIsFirst(stage: .awaitingReply, sentByViewer: false))
        XCTAssertFalse(MessageMatch.viewerIsFirst(stage: .roundResolved, sentByViewer: true))
        XCTAssertTrue(MessageMatch.viewerIsFirst(stage: .matchResolved, sentByViewer: false))

        var match = MessageMatch(seed: 3)
        match.recordFirst(.init(streak: 2, elapsedMilliseconds: 2_000))
        match.recordSecond(.init(streak: 5, elapsedMilliseconds: 2_000))
        XCTAssertEqual(match.score(viewerIsFirst: true).mine, 0)
        XCTAssertEqual(match.score(viewerIsFirst: false).mine, 1)
        XCTAssertFalse(match.rounds[0].decidedByTime)
    }

    func testMatchScoreCountsResolvedRoundsOnly() {
        var match = MessageMatch(seed: 1)
        match.recordFirst(.init(streak: 3, elapsedMilliseconds: 2_000))
        match.recordSecond(.init(streak: 2, elapsedMilliseconds: 2_000))
        XCTAssertEqual(match.score.first, 1)
        XCTAssertEqual(match.score.second, 0)
    }
}
