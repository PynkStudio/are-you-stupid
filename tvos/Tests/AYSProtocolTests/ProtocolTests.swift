import XCTest
@testable import AYSProtocol

/// Cross-checks the Swift mirror against the golden fixtures emitted by the
/// Dart codec (`tool/gen_protocol_fixtures.dart`). If the Dart protocol
/// changes, regenerate the fixture and this suite protects the Swift side.
final class ProtocolTests: XCTestCase {

    private func goldenLines() throws -> [String] {
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/messages.golden.jsonl")
        let text = try String(contentsOf: fixture, encoding: .utf8)
        return text.split(whereSeparator: \.isNewline).map(String.init)
    }

    private func decodeGolden() throws -> [any PartyMessage] {
        var out: [any PartyMessage] = []
        for line in try goldenLines() {
            switch PartyProtocol.decode(line) {
            case .ok(let message): out.append(message)
            case let .unknownType(t): XCTFail("golden line unreachable type \(t) in Swift: \(line)")
            case let .malformed(r): XCTFail("golden line malformed in Swift: \(r) :: \(line)")
            }
        }
        return out
    }

    private func decodeGolden<T: PartyMessage>(_ type: T.Type) throws -> [T] {
        try decodeGolden().compactMap { $0 as? T }
    }

    // MARK: - Fixture integrity

    func test_goldenLineCount() throws {
        XCTAssertEqual(try goldenLines().count, 34, "Dart codec emitted 34 representative messages")
    }

    func test_everyGoldenLineDecodes() throws {
        XCTAssertEqual(try decodeGolden().count, 34)
    }

    // MARK: - Lifecycle messages match the Dart codec output

    func test_helloMatchesGolden() throws {
        let hellos = try decodeGolden(Hello.self)
        XCTAssertEqual(hellos.count, 1)
        let hello = try XCTUnwrap(hellos.first)
        XCTAssertEqual(hello.type, "HELLO")
        XCTAssertEqual(hello.ts, 100)
        XCTAssertEqual(hello.appName, "AreYouStupid")
        XCTAssertEqual(hello.appVersion, "1.0")
    }

    func test_hostHelloMatchesGolden() throws {
        let host = try XCTUnwrap(try decodeGolden(HostHello.self).first)
        XCTAssertEqual(host.type, "HOST_HELLO")
        XCTAssertEqual(host.hostName, "Living Room TV")
        XCTAssertEqual(host.roomCode, "7F4K")
        XCTAssertEqual(host.maxPlayers, 8)
        XCTAssertEqual(host.protocolFeatures, ["lss", "battle", "count"])
    }

    func test_rejectedMatchesGolden() throws {
        let rejected = try XCTUnwrap(try decodeGolden(Rejected.self).first)
        XCTAssertEqual(rejected.reason, "protocol version mismatch")
    }

    func test_leaveRoomCarriesNoBody() throws {
        let leave = try XCTUnwrap(try decodeGolden(LeaveRoom.self).first)
        XCTAssertEqual(leave.type, "LEAVE_ROOM")
        XCTAssertEqual(leave.ts, 600)
    }

    func test_playerJoinedRosterMatchesGolden() throws {
        let joined = try XCTUnwrap(try decodeGolden(PlayerJoined.self).first)
        XCTAssertEqual(joined.selfClientId, "c1")
        XCTAssertEqual(joined.roomId, "7F4K")
        XCTAssertEqual(joined.players.count, 1)
        XCTAssertEqual(joined.players[0].playerName, "SAMI")
        XCTAssertEqual(joined.players[0].ready, false)
    }

    func test_startGameMatchesGolden() throws {
        let start = try XCTUnwrap(try decodeGolden(StartGame.self).first)
        XCTAssertEqual(start.mode, .stupidBattle)
        XCTAssertEqual(start.config["totalRounds"] as? Int, 20)
    }

    func test_gameEndWinnerAndMode() throws {
        let ends = try decodeGolden(GameEnd.self)
        XCTAssertEqual(ends.count, 2)

        let lss = try XCTUnwrap(ends.first { $0.mode == .lastStupidStanding })
        XCTAssertEqual(lss.winnerId, "c1")
        XCTAssertEqual(lss.results.count, 2)
        XCTAssertEqual(lss.results[0].lives, 2)
        XCTAssertEqual(lss.results[1].lives, nil)

        let battle = try XCTUnwrap(ends.first { $0.mode == .stupidBattle })
        XCTAssertNil(battle.winnerId, "absent winnerId stays nil, not empty string")
        XCTAssertEqual(battle.results.first?.score, 250)
    }

    // MARK: - Round messages match the Dart codec output

    func test_roundStartMatchesGolden() throws {
        let start = try XCTUnwrap(try decodeGolden(RoundStart.self).first)
        XCTAssertEqual(start.roundId, "r1")
        XCTAssertEqual(start.challengeId, "ch_tap_twice")
        XCTAssertEqual(start.seed, 42)
        XCTAssertEqual(start.startAt, 5000)
        XCTAssertEqual(start.durationMs, 8000)
        XCTAssertEqual(start.config["level"] as? Int, 12)
    }

    func test_roundCountdownMatchesGolden() throws {
        let countdown = try XCTUnwrap(try decodeGolden(RoundCountdown.self).first)
        XCTAssertEqual(countdown.state, "GO")
        XCTAssertEqual(countdown.atMs, 5000)
    }

    func test_playerActionTapAndCount() throws {
        let actions = try decodeGolden(PlayerAction.self)
        XCTAssertEqual(actions.count, 2)

        let tap = try XCTUnwrap(actions.first { $0.action.kind == "tap" })
        XCTAssertEqual(tap.action.targetId, "t_1")
        XCTAssertEqual(tap.action.index, 2)
        XCTAssertNil(tap.action.count)
        XCTAssertEqual(tap.clientTimestampMs, 5100)
        XCTAssertEqual(tap.playerId, "c1")

        let count = try XCTUnwrap(actions.first { $0.action.kind == "count" })
        XCTAssertEqual(count.action.count, 3)
        XCTAssertNil(count.action.targetId)
        XCTAssertEqual(count.clientTimestampMs, 0, "count wire carries explicit 0 by default")
    }

    func test_roundResultOptionalFields() throws {
        let results = try decodeGolden(RoundResult.self)
        XCTAssertEqual(results.count, 2)

        let full = try XCTUnwrap(results.first { $0.correct })
        XCTAssertEqual(full.reason, "nice")
        XCTAssertEqual(full.scoreDelta, 100)
        XCTAssertEqual(full.actionReceivedMs, 5210)

        let minimal = try XCTUnwrap(results.first { !$0.correct })
        XCTAssertEqual(minimal.reason, "")
        XCTAssertNil(minimal.actionReceivedMs)
    }

    func test_roundResultsAggregateMatchesGolden() throws {
        let reveal = try XCTUnwrap(try decodeGolden(RoundResults.self).first)
        XCTAssertEqual(reveal.roundId, "r1")
        XCTAssertEqual(reveal.results.count, 2)
        XCTAssertEqual(reveal.results[0].reactionMs, 210)
        XCTAssertEqual(reveal.results[1].correct, false)
    }

    func test_playerScoreLivesPresentAndAbsent() throws {
        let scores = try decodeGolden(PlayerScore.self)
        XCTAssertEqual(scores.count, 2)

        let battle = try XCTUnwrap(scores.first { $0.mode == .stupidBattle })
        XCTAssertEqual(battle.score, 250)
        XCTAssertNil(battle.lives)
        XCTAssertEqual(battle.standing, 1)

        let lss = try XCTUnwrap(scores.first { $0.mode == .lastStupidStanding })
        XCTAssertEqual(lss.lives, 2)
        XCTAssertEqual(lss.score, 1)
    }

    func test_errorMatchesGolden() throws {
        let error = try XCTUnwrap(try decodeGolden(PartyError.self).first)
        XCTAssertEqual(error.type, "ERROR")
        XCTAssertEqual(error.code, "ROOM_FULL")
        XCTAssertEqual(error.detail, "8/8 players")
    }

    // MARK: - AI Director messages (Phase 7) match the Dart codec

    func test_aiCapabilitiesMatchesGolden() throws {
        let capabilities = try decodeGolden(AiCapabilities.self)
        XCTAssertEqual(capabilities.count, 2)

        let available = try XCTUnwrap(capabilities.first { $0.aiAvailable })
        XCTAssertEqual(available.computeRank, 1)
        XCTAssertEqual(available.batteryPercent, 87)

        let unavailable = try XCTUnwrap(capabilities.first { !$0.aiAvailable })
        XCTAssertEqual(unavailable.computeRank, 0)
        XCTAssertEqual(unavailable.batteryPercent, 100) // default, field omitted upstream
    }

    func test_aiDirectorAssignmentPresentAndNil() throws {
        let assignments = try decodeGolden(AiDirectorAssignment.self)
        XCTAssertEqual(assignments.count, 2)
        XCTAssertEqual(assignments[0].directorPeerId, "c1")
        XCTAssertNil(assignments[1].directorPeerId)
    }

    func test_aiRoundProposalMatchesGolden() throws {
        let proposal = try XCTUnwrap(try decodeGolden(AiRoundProposal.self).first)
        XCTAssertEqual(proposal.roundId, "r2")
        XCTAssertEqual(proposal.proposal["id"] as? String, "ai.abc12")
        let mechanic = try XCTUnwrap(proposal.proposal["mechanic"] as? [String: Any])
        XCTAssertEqual(mechanic["move"] as? String, "tap_true_color")
    }

    func test_aiChallengeRoundMatchesGolden() throws {
        let round = try XCTUnwrap(try decodeGolden(AiChallengeRound.self).first)
        XCTAssertEqual(round.roundId, "r2")
        XCTAssertEqual(round.startAt, 6000)
        XCTAssertEqual(round.durationMs, 4500)
        XCTAssertEqual(round.proposal["source"] as? String, "ai")
    }

    func test_aiCommentaryProposalMatchesGolden() throws {
        let commentary = try XCTUnwrap(try decodeGolden(AiCommentaryProposal.self).first)
        XCTAssertEqual(commentary.kind, "wrong")
        XCTAssertEqual(commentary.roundId, "r2")
        XCTAssertEqual(commentary.text, "Barely made it.")
    }

    func test_aiCommentaryMatchesGolden() throws {
        let commentary = try XCTUnwrap(try decodeGolden(AiCommentary.self).first)
        XCTAssertEqual(commentary.kind, "elimination")
        XCTAssertEqual(commentary.text, "Gone, but not forgotten.")
    }

    // MARK: - Forward tolerance (same rules as the Dart codec)

    func test_unknownFieldsAreIgnored() throws {
        let line = #"{"protocolVersion":1,"type":"HELLO","ts":7,"appName":"X","appVersion":"9","futureField":{"nested":true}}"#
        switch PartyProtocol.decode(line) {
        case .ok(let message as Hello):
            XCTAssertEqual(message.appName, "X")
            XCTAssertEqual(message.ts, 7)
        default:
            XCTFail("extra known-ignored fields must not break decoding")
        }
    }

    func test_unknownTypeIsTolerated() throws {
        let line = #"{"protocolVersion":1,"type":"FUTURE_MESSAGE","ts":1}"#
        switch PartyProtocol.decode(line) {
        case .unknownType("FUTURE_MESSAGE"):
            break // caller ignores it and waits
        default:
            XCTFail("unknown type must surface as .unknownType")
        }
    }

    func test_malformedInput() {
        func expectMalformed(_ input: String, _ reason: String, file: StaticString = #filePath, line: UInt = #line) {
            switch PartyProtocol.decode(input) {
            case .malformed(let r) where r == reason: break
            default: XCTFail("expected \(reason), got \(input)", file: file, line: line)
            }
        }
        expectMalformed("", "not JSON / not an object")
        expectMalformed("not json", "not JSON / not an object")
        expectMalformed("[]", "not JSON / not an object")
        expectMalformed(#"{"foo":1}"#, "missing type")
        expectMalformed(#"{"type":""}"#, "missing type")
    }

    func test_unknownModeDefaultsToBattleLikeDart() throws {
        let gameEnd = PartyProtocol.decode(#"{"protocolVersion":1,"type":"GAME_END","ts":0,"mode":"future_mode","results":[]}"#)
        guard case .ok(let message as GameEnd) = gameEnd else {
            return XCTFail("GameEnd should decode with default mode")
        }
        XCTAssertEqual(message.mode, .stupidBattle, "Dart falls back to battle for unknown modes")
    }

    // MARK: - Swift round-trip consistency

    func test_roundTripHello() throws {
        let hello = Hello(appName: "AreYouStupid", appVersion: "1.0", ts: 11)
        guard case .ok(let decoded as Hello) = try PartyProtocol.roundTrip(hello) else {
            return XCTFail("hello must round-trip")
        }
        XCTAssertEqual(hello, decoded)
    }

    func test_roundTripRoundStartPreservesConfig() throws {
        let start = RoundStart(
            roundId: "r9",
            challengeId: "ch_tap_exactly_n",
            seed: 7,
            startAt: 9000,
            durationMs: 8000,
            config: ["level": 21, "strike": true],
            ts: 42
        )
        guard case .ok(let decoded as RoundStart) = try PartyProtocol.roundTrip(start) else {
            return XCTFail("round start must round-trip")
        }
        XCTAssertEqual(decoded.challengeId, "ch_tap_exactly_n")
        XCTAssertEqual(decoded.seed, 7)
        XCTAssertEqual(decoded.config["level"] as? Int, 21)
        XCTAssertEqual(decoded.config["strike"] as? Bool, true)
    }

    func test_goldenReserializesIdempotently() throws {
        let start = try XCTUnwrap(try decodeGolden(RoundStart.self).first)
        let reencoded = try PartyProtocol.encode(start)
        guard case .ok(let twice as RoundStart) = PartyProtocol.decode(reencoded) else {
            return XCTFail("re-encoded golden must decode")
        }
        XCTAssertEqual(twice.challengeId, start.challengeId)
        XCTAssertEqual(twice.seed, start.seed)
        XCTAssertEqual(twice.config["level"] as? Int, 12)
    }
}