//
//  HostViewModel.swift
//  AYSHost
//
//  Wires AYSHostCore (RoomHost, NWListenerServer, QRGenerator) to SwiftUI.
//  This is the first place all three actually run together as a real app
//  instead of headless test doubles ([[Multiplayer Host (tvOS)]]).
//
//  Networking is started from `.task {}`, not `init`, and never blocks the
//  UI: if the OS "Local Network" permission prompt is pending, the Lobby
//  still renders (room code + QR) with a "waiting for network…" status —
//  see docs/Meta/Decision Log.md on why that prompt can hang a *headless*
//  process, which does not apply here (a real windowed app has a run loop
//  and a user who can answer it).
//

import AYSHostCore
import AYSProtocol
import Foundation
import SwiftUI

enum BoardScreen: Equatable {
    case lobby
    case round(roundId: String)
    case results(results: [PlayerRoundResult], roundId: String)
    case gameEnd(GameEnd)
}

@MainActor
final class HostViewModel: ObservableObject {
    @Published private(set) var roomCode: String
    @Published private(set) var roster: [PlayerInfo] = []
    @Published private(set) var screen: BoardScreen = .lobby
    @Published private(set) var countdownState: String?
    @Published private(set) var networkStatus = "STARTING…"
    @Published private(set) var lastError: String?

    /// The elected AI Director's display name, or `nil` when no capable
    /// phone is connected — the match plays 100% scripted either way
    /// ([[Multiplayer AI Director]] Phase 8). Resolved from `roster` by
    /// peer id since `AI_DIRECTOR_ASSIGNMENT` only carries the id.
    @Published private(set) var directorName: String?

    /// The most recent AI commentary line relayed by the Director, if any.
    /// Not yet shown anywhere in the UI — captured for the next targeted
    /// pass, same as [[Pre-generation Cache]]'s commentary ring on the
    /// single-player side.
    @Published private(set) var lastAiCommentary: String?

    /// Live per-player standings, keyed by `playerId` — populated from every
    /// `PLAYER_SCORE` broadcast (`RoomHost.applyScoring` sends one per seat
    /// after every round, win or lose) so a scoreboard can render without
    /// waiting for `GAME_END`. Cleared on every new game (`startGame`) so a
    /// rematch never shows a stale score from the previous match.
    @Published private(set) var standings: [String: PlayerScore] = [:]

    /// The mode the *next* `startGame()` call uses — set from the Lobby's
    /// mode picker before the match starts. Persists across a rematch
    /// (`rematch()` returns to `.lobby` without resetting it) so the host
    /// doesn't have to re-pick it every time.
    @Published var selectedMode: GameMode = .stupidBattle

    private let host: RoomHost
    private let server = NWListenerServer()

    var readyCount: Int { roster.filter(\.ready).count }
    var canStart: Bool { readyCount >= 2 && screen == .lobby }

    /// Standings sorted for display: highest score (Battle) or most lives
    /// then highest score (LSS) first, ties broken by name so the order
    /// doesn't jitter round to round for equal scores.
    var sortedStandings: [PlayerScore] {
        standings.values.sorted { a, b in
            if let la = a.lives, let lb = b.lives, la != lb { return la > lb }
            if a.score != b.score { return a.score > b.score }
            return name(for: a.playerId) < name(for: b.playerId)
        }
    }

    func name(for playerId: String) -> String {
        roster.first(where: { $0.playerId == playerId })?.playerName.uppercased() ?? playerId
    }

    init() {
        let code = RoomCode.random()
        roomCode = code
        host = RoomHost(
            hostName: "ARE YOU STUPID?",
            roomCode: code,
            clock: SystemHostClock(),
            judge: RoundDurationProvider()
        )
        host.onBroadcast = { [weak self] message in
            Task { @MainActor in self?.handle(message) }
        }
    }

    func startHosting() async {
        server.onNewTransport = { [weak self] transport in
            self?.host.attachClient(transport)
        }
        do {
            let port = try await server.start(advertising: BonjourService(roomCode: roomCode))
            networkStatus = "LISTENING ON PORT \(port)"
        } catch {
            networkStatus = "NETWORK UNAVAILABLE"
            lastError = "\(error)"
        }
    }

    func stopHosting() {
        server.stop()
        host.close()
    }

    func startGame() {
        standings = [:]
        lastAiCommentary = nil
        do {
            try host.startGame(mode: selectedMode)
            try host.startNextRound(level: 5)
        } catch {
            lastError = "\(error)"
        }
    }

    func nextRound() {
        guard host.isInGame else { return }
        do {
            try host.startNextRound(level: 5)
        } catch {
            lastError = "\(error)"
        }
    }

    func completeRound() {
        host.completeRound()
    }

    /// "No downtime" (docs/Gameplay/Game Design Pillars.md) applies to the
    /// board too: the round closes itself on the shared deadline, no host
    /// button to press. This is the *backstop* half of that rule — `RoomHost`
    /// itself now also closes a round the instant every alive seat has
    /// answered, which usually fires first; whichever happens first wins
    /// and the other is a harmless no-op (`RoomHost.completeRound()` guards
    /// on `!round.ended`), including a stale timer from a superseded round.
    private func scheduleAutoComplete(roundId: String, closesAt: Int) {
        let waitMs = max(0, closesAt - host.nowMs)
        Task {
            try? await Task.sleep(nanoseconds: UInt64(waitMs) * 1_000_000)
            guard host.openRoundId == roundId else { return }
            completeRound()
        }
    }

    /// The other half of "no downtime": once results are up, move on to the
    /// next round without a host tap. `resultsPause` is how long the board
    /// holds on the reveal before advancing — short on purpose (docs/
    /// Gameplay/Multiplayer Gameplay.md "transitions are short, never long
    /// animations"). Guards on `screen` still being these exact results when
    /// the pause elapses: a `GAME_END` arriving in the same broadcast burst
    /// as `ROUND_RESULTS` (the match just got decided) already overwrote
    /// `screen` by the time this runs, and this must not then also start a
    /// round nobody asked for.
    private func scheduleAutoAdvance(afterRoundId roundId: String) {
        let resultsPause: UInt64 = 2_500_000_000
        Task {
            try? await Task.sleep(nanoseconds: resultsPause)
            guard case .results(_, let forRoundId) = screen, forRoundId == roundId else { return }
            nextRound()
        }
    }

    var joinQRImage: Image {
        if let cgImage = QRGenerator.joinCode(roomCode: roomCode) {
            return Image(decorative: cgImage, scale: 1, orientation: .up)
        }
        return Image(systemName: "qrcode")
    }

    var joinDeepLink: String { QRGenerator.joinDeepLink(roomCode: roomCode) }

    private func handle(_ message: any PartyMessage) {
        switch message {
        case let m as PlayerReadyRoster:
            roster = m.players
        case let m as RoundStart:
            screen = .round(roundId: m.roundId)
            countdownState = nil
            scheduleAutoComplete(roundId: m.roundId, closesAt: m.startAt + m.durationMs)
        case let m as RoundCountdown:
            countdownState = m.state
        case let m as RoundResults:
            screen = .results(results: m.results, roundId: m.roundId)
            scheduleAutoAdvance(afterRoundId: m.roundId)
        case let m as PlayerScore:
            standings[m.playerId] = m
        case let m as GameEnd:
            screen = .gameEnd(m)
        case let m as AiDirectorAssignment:
            directorName = m.directorPeerId.map(name(for:))
        case let m as AiChallengeRound:
            screen = .round(roundId: m.roundId)
            countdownState = nil
            scheduleAutoComplete(roundId: m.roundId, closesAt: m.startAt + m.durationMs)
        case let m as AiCommentary:
            lastAiCommentary = m.text
        default:
            break
        }
    }

    /// "Instant rematch back into the lobby" (docs/Gameplay/Multiplayer
    /// Gameplay.md) — same room, same connections, same room code, so
    /// nobody re-scans the QR. Players re-ready (`startGame` already reset
    /// everyone's `ready` flag when this match began) and `startGame` runs
    /// again from `canStart`, same as the first game.
    func rematch() {
        screen = .lobby
        countdownState = nil
    }
}
