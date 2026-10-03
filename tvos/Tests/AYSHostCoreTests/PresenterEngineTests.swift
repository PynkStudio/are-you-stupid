import XCTest
@testable import AYSHostCore

final class PresenterEngineTests: XCTestCase {
    func testUniversalCueUsesVersionedOfflinePack() {
        let cue = PresenterEngine().lobbyEmpty()
        XCTAssertTrue(cue.id.hasPrefix("pack.v1.lobby.empty."))
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
}
