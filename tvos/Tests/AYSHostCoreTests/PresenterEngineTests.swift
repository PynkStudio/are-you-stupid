import XCTest
@testable import AYSHostCore

final class PresenterEngineTests: XCTestCase {
    func testUniversalCueUsesVersionedOfflinePack() throws {
        let cue = try XCTUnwrap(PresenterEngine().lobbyEmpty())
        XCTAssertTrue(cue.id.hasPrefix("pack.lobby.empty."))
        XCTAssertEqual(cue.expiry, .whileLobby)
        XCTAssertTrue(cue.cacheable)
    }

    func testHomonymsBecomeRealAndOtherName() {
        let engine = PresenterEngine()
        let players = [
            PresenterPlayer(id: "1", displayName: "x_Luca_x", spokenName: "Luca"),
            PresenterPlayer(id: "2", displayName: "Luca🔥", spokenName: "Luca"),
        ]
        XCTAssertEqual(engine.disambiguatedName(for: players[0], among: players), "IL VERO LUCA")
        XCTAssertEqual(engine.disambiguatedName(for: players[1], among: players), "L'ALTRO LUCA")
        let english = PresenterEngine(lineBook: .builtIn(locale: "en"))
        XCTAssertEqual(english.disambiguatedName(for: players[1], among: players), "THE OTHER LUCA")
    }

    func testSavageTitleRequiresSavageModeAndVerifiedStreak() {
        let player = PresenterPlayer(id: "1", displayName: "Luca", spokenName: "Luca")
        let fact = { PresenterRoundFact(roundId: UUID().uuidString, correctPlayerIds: [], wrongPlayerIds: ["1"]) }
        let neutral = PresenterEngine(intensity: .neutral)
        XCTAssertFalse((0..<3).flatMap { _ in neutral.roundResult(fact(), players: [player]) }.contains { $0.kind == .title })
        let savage = PresenterEngine(intensity: .savage)
        let cues = (0..<3).flatMap { _ in savage.roundResult(fact(), players: [player]) }
        XCTAssertTrue(cues.contains { $0.text.contains("QUELLO CHE NON LEGGE") })
    }

    func testRoundResultExpiryCarriesRoundIdentity() {
        let cue = PresenterEngine().roundResult(.init(roundId: "r7", correctPlayerIds: [], wrongPlayerIds: ["1"]), players: [PresenterPlayer(id: "1", displayName: "A")]).first
        XCTAssertEqual(cue?.expiry, .throughResults(roundId: "r7"))
    }

    func testChallengeIdsMapToStableEditorialMechanics() {
        XCTAssertEqual(PresenterMechanic(challengeId: "tap_color"), .button)
        XCTAssertEqual(PresenterMechanic(challengeId: "math"), .math)
        XCTAssertEqual(PresenterMechanic(challengeId: "count_shapes"), .counting)
        XCTAssertEqual(PresenterMechanic(challengeId: "tap_the_word"), .reading)
        XCTAssertEqual(PresenterMechanic(challengeId: "wait_for_green"), .waiting)
        XCTAssertEqual(PresenterMechanic(challengeId: "precise_timing"), .timing)
        XCTAssertEqual(PresenterMechanic(challengeId: "remember_color"), .memory)
        XCTAssertEqual(PresenterMechanic(challengeId: "left_right_swap"), .direction)
        XCTAssertEqual(PresenterMechanic(challengeId: "spot_different"), .perception)
        XCTAssertNil(PresenterMechanic(challengeId: "ai"))
        XCTAssertEqual(AYSChallengeCatalog.all.compactMap { PresenterMechanic(challengeId: $0.id) }.count, AYSChallengeCatalog.all.count)
    }

    func testSavageOneWrongUsesNamedMechanicCopy() {
        let engine = PresenterEngine(intensity: .savage)
        let players = [
            PresenterPlayer(id: "1", displayName: "Luca", spokenName: "Luca"),
            PresenterPlayer(id: "2", displayName: "Mara", spokenName: "Mara"),
        ]
        let cue = engine.roundResult(.init(
            roundId: "r1", correctPlayerIds: ["2"], wrongPlayerIds: ["1"], challengeId: "math"
        ), players: players)[0]
        XCTAssertEqual(cue.targetPlayerId, "1")
        XCTAssertTrue(cue.text.contains("LUCA"))
        XCTAssertTrue(cue.text.contains("NUMERI") || cue.text.contains("ELEMENTARI"))
    }

    func testNeutralModeNeverUsesSavageMechanicTemplate() {
        let engine = PresenterEngine(intensity: .neutral)
        let players = [
            PresenterPlayer(id: "1", displayName: "Luca", spokenName: "Luca"),
            PresenterPlayer(id: "2", displayName: "Mara", spokenName: "Mara"),
        ]
        let cue = engine.roundResult(.init(
            roundId: "r1", correctPlayerIds: ["2"], wrongPlayerIds: ["1"], challengeId: "math"
        ), players: players)[0]
        XCTAssertNil(cue.targetPlayerId)
        XCTAssertFalse(cue.text.contains("LUCA"))
    }

    func testLateFirstPointAndPersistentZeroComeFromVerifiedLedger() {
        let late = PresenterEngine(intensity: .savage)
        let luca = PresenterPlayer(id: "1", displayName: "Luca", spokenName: "Luca")
        for round in 1...3 {
            _ = late.roundResult(.init(roundId: "r\(round)", correctPlayerIds: [], wrongPlayerIds: ["1"]), players: [luca])
        }
        let firstPoint = late.roundResult(.init(roundId: "r4", correctPlayerIds: ["1"], wrongPlayerIds: []), players: [luca])[0]
        XCTAssertTrue(firstPoint.text.contains("GARA") || firstPoint.text.contains("REGIA"))

        let zero = PresenterEngine(intensity: .savage)
        let mara = PresenterPlayer(id: "2", displayName: "Mara", spokenName: "Mara")
        for round in 1...3 {
            _ = zero.roundResult(.init(roundId: "z\(round)", correctPlayerIds: [], wrongPlayerIds: ["1", "2"]), players: [luca, mara])
        }
        let stillZero = zero.roundResult(.init(roundId: "z4", correctPlayerIds: [], wrongPlayerIds: ["1", "2"]), players: [luca, mara])[0]
        XCTAssertEqual(stillZero.targetPlayerId, "1")
        XCTAssertTrue(stillZero.text.contains("PUNTI"))
        // The same fact next round: the spent joke is not told again.
        let next = zero.roundResult(.init(roundId: "z5", correctPlayerIds: [], wrongPlayerIds: ["1", "2"]), players: [luca, mara])
        XCTAssertFalse(next.contains { $0.text == stillZero.text })
    }

    func testLastStupidStandingUsesLivesInsteadOfPointCopy() {
        let engine = PresenterEngine(intensity: .savage)
        let luca = PresenterPlayer(id: "1", displayName: "Luca", spokenName: "Luca")
        _ = engine.roundResult(.init(
            roundId: "r1", correctPlayerIds: [], wrongPlayerIds: ["1"],
            mode: .lastStupidStanding, remainingLivesByPlayer: ["1": 2]
        ), players: [luca])
        let cue = engine.roundResult(.init(
            roundId: "r2", correctPlayerIds: [], wrongPlayerIds: ["1"],
            mode: .lastStupidStanding, remainingLivesByPlayer: ["1": 1]
        ), players: [luca])[0]
        XCTAssertTrue(cue.text.contains("VITA") || cue.text.contains("VITE") || cue.text.contains("RESTA"))
        XCTAssertFalse(cue.text.contains("PUNTI"))
    }

    func testTitleRoundEmitsOneCombinedCue() {
        let engine = PresenterEngine(intensity: .savage)
        let luca = PresenterPlayer(id: "1", displayName: "Luca", spokenName: "Luca")
        for round in 1...3 {
            _ = engine.roundResult(.init(roundId: "r\(round)", correctPlayerIds: ["1"], wrongPlayerIds: []), players: [luca])
        }
        let cues = engine.roundResult(.init(roundId: "r4", correctPlayerIds: ["1"], wrongPlayerIds: []), players: [luca])
        XCTAssertEqual(cues.count, 1)
        XCTAssertEqual(cues[0].kind, .title)
        XCTAssertTrue(cues[0].text.contains("PUNTO") && cues[0].text.contains("KING"))
    }

    // MARK: - Repetition guard

    func testRecurringGenericOutcomePrefersSilenceToARepeat() {
        let engine = PresenterEngine(intensity: .neutral)
        let luca = PresenterPlayer(id: "1", displayName: "Luca", spokenName: "Luca")
        var lastRoundByText: [String: Int] = [:]
        var silentRounds = 0
        for round in 1...14 {
            let cues = engine.roundResult(.init(roundId: "r\(round)", correctPlayerIds: [], wrongPlayerIds: ["1"]), players: [luca])
            if cues.isEmpty { silentRounds += 1 }
            for cue in cues {
                if let last = lastRoundByText[cue.text] {
                    XCTAssertGreaterThanOrEqual(round - last, PresenterLineHistory.cooldownBeats, cue.text)
                }
                lastRoundByText[cue.text] = round
            }
        }
        XCTAssertGreaterThan(silentRounds, 0)
    }

    func testSameMechanicFailureVariesThenEscalatesThenGoesQuiet() {
        let engine = PresenterEngine(intensity: .savage)
        let players = [
            PresenterPlayer(id: "1", displayName: "Chiara", spokenName: "Chiara"),
            PresenterPlayer(id: "2", displayName: "Mara", spokenName: "Mara"),
        ]
        var texts: [String] = []
        for round in 1...8 {
            let cues = engine.roundResult(.init(
                roundId: "r\(round)", correctPlayerIds: ["2"], wrongPlayerIds: ["1"], challengeId: "tap_color"
            ), players: players)
            texts += cues.map(\.text)
        }
        XCTAssertEqual(texts.count, Set(texts).count, "no line may be told twice in one match: \(texts)")
        XCTAssertTrue(texts.contains { $0.contains("BOTTONE") })
        XCTAssertTrue(texts.contains { $0.contains("ANCORA TU") || $0.contains("DI NUOVO") || $0.contains("LA REGIA") })
    }

    func testSameJokeAimedAtAnotherPlayerIsStillARepeat() {
        let engine = PresenterEngine(intensity: .savage)
        let players = [
            PresenterPlayer(id: "1", displayName: "Luca", spokenName: "Luca"),
            PresenterPlayer(id: "2", displayName: "Mara", spokenName: "Mara"),
        ]
        let first = engine.roundResult(.init(roundId: "r1", correctPlayerIds: ["2"], wrongPlayerIds: ["1"]), players: players)
        let second = engine.roundResult(.init(roundId: "r2", correctPlayerIds: ["1"], wrongPlayerIds: ["2"]), players: players)
        XCTAssertEqual(first.first?.text.contains("SPIEGO"), true)
        XCTAssertFalse(second.contains { $0.text.contains("SPIEGO") })
    }

    func testNearDuplicatesShareASignature() {
        XCTAssertEqual(
            PresenterLineHistory.signatures(of: "RISULTATI MISTI. MOLTO MISTI."),
            PresenterLineHistory.signatures(of: "Risultati misti... molto misti!")
        )
        // Different setup, same punchline: one joke.
        var history = PresenterLineHistory()
        history.record("ABBIAMO UN VINCITORE. TECNICAMENTE.")
        XCTAssertFalse(history.allows("{name} HA VINTO. TECNICAMENTE.", oncePerMatch: false))
        XCTAssertTrue(history.allows("NESSUNO HA LETTO. PERFETTO.", oncePerMatch: false))
    }

    func testCooldownAndOncePerMatchRules() {
        var history = PresenterLineHistory()
        history.record("{name}, ERA UN BOTTONE.")
        for index in 0..<PresenterLineHistory.cooldownBeats {
            XCTAssertFalse(history.allows("{name}, ERA UN BOTTONE.", oncePerMatch: false), "beat \(index)")
            history.advance()
        }
        XCTAssertTrue(history.allows("{name}, ERA UN BOTTONE.", oncePerMatch: false))
        XCTAssertFalse(history.allows("{name}, ERA UN BOTTONE.", oncePerMatch: true))
        history.beginMatch()
        XCTAssertTrue(history.allows("{name}, ERA UN BOTTONE.", oncePerMatch: true))
    }
}
