//
//  BoardSnapshotTests.swift
//
//  Renders every in-game board state from fixtures. Always checks that each
//  state lays out and rasterizes; with AYS_BOARD_SNAPSHOT_DIR set it also
//  writes the PNGs there for a visual review (docs/Development/Testing.md).
//

import AYSProtocol
import SwiftUI
import XCTest
@testable import AYSHostUI

@MainActor
final class BoardSnapshotTests: XCTestCase {
    private let names = ["LUCA", "GIULIA", "MARCO", "SOFIA", "ANDREA", "CHIARA", "PAOLO",
                         "ELENA", "MATTEO", "SARA", "DAVIDE", "MARTA"]
    private let emojis = ["🦊", "🐸", "🤡", "🦄", "🐙", "🍕", "🧠", "🐼", "👽", "🦖", "🌵", "🐝"]

    private func roster(_ count: Int) -> [PlayerInfo] {
        (0..<count).map { PlayerInfo(playerId: "p\($0)", playerName: names[$0], emoji: emojis[$0], ready: true) }
    }

    private func battle(_ scores: [Int]) -> [PlayerScore] {
        scores.enumerated().map { PlayerScore(playerId: "p\($0.offset)", mode: .stupidBattle, score: $0.element) }
    }

    private func lss(_ lives: [Int]) -> [PlayerScore] {
        lives.enumerated().map { PlayerScore(playerId: "p\($0.offset)", mode: .lastStupidStanding, score: 0, lives: $0.element) }
    }

    private func render(_ name: String, _ model: HostViewModel,
                        sizes: [CGSize] = [CGSize(width: 1280, height: 720)],
                        scale: CGFloat = 1, directory: String? = nil) throws {
        let directory = directory ?? ProcessInfo.processInfo.environment["AYS_BOARD_SNAPSHOT_DIR"]
        for size in sizes {
            let view = BoardScreens(model: model)
                .frame(width: size.width, height: size.height)
                .environment(\.boardStill, true)
                .foregroundStyle(.white)
            let renderer = ImageRenderer(content: view)
            renderer.scale = scale
            let image = try XCTUnwrap(renderer.cgImage, "\(name) did not render")
            XCTAssertEqual(CGFloat(image.width), size.width * scale)
            if let directory,
               let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                let suffix = scale == 1 ? "-\(Int(size.width))" : ""
                let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name)\(suffix).png")
                try png.write(to: url)
            }
        }
    }

    private var stats: [String: PlayerMatchStats] {
        var stats: [String: PlayerMatchStats] = [:]
        let rows: [(Int, Int, Int?, Int)] = [(17, 3, 480, 9), (15, 5, 610, 6), (12, 8, 700, 4),
                                             (11, 9, 550, 3), (10, 10, 820, 2), (6, 14, 900, 2), (9, 11, 760, 3)]
        for (index, row) in rows.enumerated() {
            stats["p\(index)"] = PlayerMatchStats(correct: row.0, wrong: row.1, bestReactionMs: row.2,
                                                  reactionTotalMs: row.0 * 910, reactionCount: row.0,
                                                  streak: 0, longestStreak: row.3)
        }
        return stats
    }

    private func battleResultsModel(locale: String = "en") -> HostViewModel {
        let model = HostViewModel()
        let results = [
            PlayerRoundResult(playerId: "p0", correct: true, scoreDelta: 100, reactionMs: 912),
            PlayerRoundResult(playerId: "p5", correct: false, reason: "Too slow."),
            PlayerRoundResult(playerId: "p4", correct: true, scoreDelta: 100, reactionMs: 1040),
            PlayerRoundResult(playerId: "p6", correct: true, scoreDelta: 100, reactionMs: 1310),
            PlayerRoundResult(playerId: "p2", correct: true, scoreDelta: 100, reactionMs: 1122),
            PlayerRoundResult(playerId: "p1", correct: true, scoreDelta: 100, reactionMs: 640),
            PlayerRoundResult(playerId: "p3", correct: false, reason: "It said tap the SMALLER one."),
        ]
        model.seedForSnapshot(
            roster: roster(7), mode: .stupidBattle, roundNumber: 7,
            standingsBefore: battle([500, 600, 400, 500, 300, 300, 400]),
            standings: battle([600, 700, 500, 500, 400, 300, 500]),
            commentary: "Some read it. Some were present.",
            locale: locale,
            screen: .results(results: results, roundId: "r7"))
        return model
    }

    func testRoundResultsBattleMixed() throws {
        try render("results-battle", battleResultsModel(), sizes: [CGSize(width: 1280, height: 720),
                                                     CGSize(width: 1920, height: 1080),
                                                     CGSize(width: 900, height: 560)])
    }

    private func eliminationResultsModel(locale: String = "en") -> HostViewModel {
        let model = HostViewModel()
        let results = [
            PlayerRoundResult(playerId: "p0", correct: true, reactionMs: 700),
            PlayerRoundResult(playerId: "p1", correct: false, reason: "Tapped the decoy."),
            PlayerRoundResult(playerId: "p2", correct: false, reason: "Too slow."),
            PlayerRoundResult(playerId: "p3", correct: true, reactionMs: 860),
        ]
        model.seedForSnapshot(
            roster: roster(5), mode: .lastStupidStanding, roundNumber: 9,
            standingsBefore: lss([3, 1, 2, 2, 0]),
            standings: lss([3, 0, 1, 2, 0]),
            commentary: "Giulia has left the building. Mentally, a while ago.",
            locale: locale,
            screen: .results(results: results, roundId: "r9"))
        return model
    }

    func testRoundResultsElimination() throws {
        try render("results-elimination", eliminationResultsModel())
    }

    func testRoundResultsEveryoneRight() throws {
        let model = HostViewModel()
        let results = (0..<5).map { PlayerRoundResult(playerId: "p\($0)", correct: true, scoreDelta: 100, reactionMs: 600 + $0 * 170) }
        model.seedForSnapshot(
            roster: roster(5), mode: .stupidBattle, roundNumber: 3,
            standingsBefore: battle([200, 200, 100, 200, 100]),
            standings: battle([300, 300, 200, 300, 200]),
            screen: .results(results: results, roundId: "r3"))
        try render("results-clean", model)
    }

    func testRoundResultsCrowdedRoom() throws {
        let model = HostViewModel()
        let results = (0..<12).map {
            PlayerRoundResult(playerId: "p\($0)", correct: $0 % 4 == 0,
                              reason: $0 % 4 == 0 ? "" : ["Too slow.", "Tapped the decoy.", "It said DON'T tap."][$0 % 3],
                              reactionMs: $0 % 4 == 0 ? 700 + $0 * 40 : nil)
        }
        model.seedForSnapshot(
            roster: roster(12), mode: .stupidBattle, roundNumber: 14,
            standingsBefore: battle((0..<12).map { 1300 - $0 * 90 }),
            standings: battle((0..<12).map { 1300 - $0 * 90 + ($0 % 4 == 0 ? 100 : 0) }),
            screen: .results(results: results, roundId: "r14"))
        try render("results-crowded", model)
    }

    private func winnerModel(locale: String = "en") -> HostViewModel {
        let model = HostViewModel()
        let scores = [1700, 1500, 1200, 1100, 1000, 600, 900]
        let order = scores.enumerated().sorted { $0.element > $1.element }
        let entries = order.enumerated().map { GameResultEntry(playerId: "p\($0.element.offset)", score: $0.element.element, standing: $0.offset + 1) }
        model.seedForSnapshot(
            roster: roster(7), mode: .stupidBattle, roundNumber: 20,
            standingsBefore: battle(scores), standings: battle(scores), stats: stats,
            commentary: "Luca wins. Statistically, someone had to.",
            locale: locale,
            screen: .gameEnd(GameEnd(mode: .stupidBattle, results: entries, winnerId: "p0")))
        return model
    }

    func testGameEndWinner() throws {
        try render("final-winner", winnerModel(), sizes: [CGSize(width: 1280, height: 720), CGSize(width: 900, height: 560)])
    }

    func testGameEndNobodySurvived() throws {
        let model = HostViewModel()
        let entries = (0..<7).map { GameResultEntry(playerId: "p\($0)", lives: 0, standing: $0 + 1) }
        model.seedForSnapshot(
            roster: roster(7), mode: .lastStupidStanding, roundNumber: 11,
            standingsBefore: lss([1, 1, 1, 0, 0, 0, 0]), standings: lss([0, 0, 0, 0, 0, 0, 0]), stats: stats,
            screen: .gameEnd(GameEnd(mode: .lastStupidStanding, results: entries, winnerId: nil)))
        try render("final-nobody", model)
    }

    func testRoundInProgress() throws {
        let model = HostViewModel()
        model.seedForSnapshot(
            roster: roster(7), mode: .stupidBattle, roundNumber: 8,
            standingsBefore: battle([600, 700, 500, 500, 400, 300, 500]),
            standings: battle([600, 700, 500, 500, 400, 300, 500]),
            screen: .round(roundId: "r8"))
        try render("round", model)
    }

    /// The board follows the room's language (the presenter locale): every
    /// state must still lay out with the longer Italian copy.
    func testBoardFollowsRoomLanguage() throws {
        let lobby = HostViewModel()
        lobby.seedForSnapshot(roster: roster(6), mode: .stupidBattle, roundNumber: 0, standingsBefore: [], standings: [],
                              networkStatus: .networkReady, locale: "it", screen: .lobby)
        let round = HostViewModel()
        round.seedForSnapshot(roster: roster(7), mode: .stupidBattle, roundNumber: 8,
                              standingsBefore: battle([600, 700, 500, 500, 400, 300, 500]),
                              standings: battle([600, 700, 500, 500, 400, 300, 500]),
                              locale: "it", screen: .round(roundId: "r8"))
        let models: [(String, HostViewModel)] = [
            ("lobby", lobby), ("round", round),
            ("results-battle", battleResultsModel(locale: "it")),
            ("results-elimination", eliminationResultsModel(locale: "it")),
            ("final-winner", winnerModel(locale: "it")),
        ]
        for (name, model) in models {
            XCTAssertEqual(model.strings.locale, "it")
            try render("it-\(name)", model, sizes: [CGSize(width: 1280, height: 720), CGSize(width: 900, height: 560)])
        }
    }

    /// Raw board captures for the App Store (Apple TV and Mac) campaigns,
    /// rendered at 2x: `AYS_STORE_CAPTURE_DIR=… swift test --filter
    /// testStoreCaptures`, then store_assets/generate_*_screenshots.py.
    func testStoreCaptures() throws {
        guard let directory = ProcessInfo.processInfo.environment["AYS_STORE_CAPTURE_DIR"] else {
            throw XCTSkip("AYS_STORE_CAPTURE_DIR not set")
        }
        let tv = [CGSize(width: 1920, height: 1080)]
        let mac = [CGSize(width: 1440, height: 900)]

        let emptyLobby = HostViewModel()
        emptyLobby.seedForSnapshot(roster: [], mode: .stupidBattle, roundNumber: 0, standingsBefore: [], standings: [],
                                   networkStatus: .networkReady, screen: .lobby)
        let fullLobby = HostViewModel()
        fullLobby.seedForSnapshot(roster: roster(6), mode: .stupidBattle, roundNumber: 0, standingsBefore: [], standings: [],
                                  networkStatus: .networkReady, screen: .lobby)
        let models: [(String, HostViewModel)] = [
            ("lobby-empty", emptyLobby), ("lobby-full", fullLobby),
            ("results-battle", battleResultsModel()), ("results-elimination", eliminationResultsModel()),
            ("final-winner", winnerModel()),
        ]
        for (name, model) in models {
            try render("tv-\(name)", model, sizes: tv, scale: 2, directory: directory)
            try render("mac-\(name)", model, sizes: mac, scale: 2, directory: directory)
        }
    }
}
