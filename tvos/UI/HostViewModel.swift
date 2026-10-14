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

enum PresenterOutputMode: String, CaseIterable {
    case off, mute, voice
}

@MainActor
final class HostViewModel: ObservableObject {
    @Published private(set) var roomCode: String
    @Published private(set) var roster: [PlayerInfo] = []
    @Published private(set) var screen: BoardScreen = .lobby
    @Published private(set) var countdownState: String?
    @Published private(set) var networkStatus = "STARTING…"
    @Published private(set) var lastError: String?
    @Published private(set) var maxPlayers = 8
    @Published private(set) var partyPackActive = false
    @Published private(set) var adBreakPlayerName: String?
    /// `"ip:port"` the join QR carries for phones whose Bonjour lookup fails
    /// (see `QRGenerator.joinDeepLink`); nil until the listener is ready.
    @Published private(set) var directHostHint: String?

    /// The elected AI Director's display name, or `nil` when no capable
    /// phone is connected — the match plays 100% scripted either way
    /// ([[Multiplayer AI Director]] Phase 8). Resolved from `roster` by
    /// peer id since `AI_DIRECTOR_ASSIGNMENT` only carries the id.
    @Published private(set) var directorName: String?

    /// The most recent AI commentary line relayed by the Director, if any.
    /// Cleared at each round boundary and shown only in results/end chrome,
    /// never over the active play state.
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
    @Published private(set) var presenterOutputMode: PresenterOutputMode = .voice
    @Published private(set) var presenterIntensity: PresenterIntensity = .savage

    private let host: RoomHost
    // Connections run on main, where this @MainActor model also drives
    // `host` (start/next/complete round): RoomHost is single-threaded.
    private let server = NWListenerServer(connectionQueue: .main)
    private let advertisedDeviceName: String
    private let presenterPacks = PresenterPackStore()
    private let presenterEngine = PresenterEngine(intensity: .savage)
    private let presenterAudio: PresenterAudioController
    private let soundEffects = HostSoundEffects()
    private let presenterCareers = PresenterCareerStore()
    private var announcedPersonas: Set<String> = []
    /// `ROUND_RESULTS` intentionally contains outcomes only. Preserve the
    /// verified challenge id from `ROUND_START` so presenter copy can roast
    /// the actual mechanic without widening the wire protocol.
    private var challengeIdByRound: [String: String] = [:]

    var readyCount: Int { roster.filter(\.ready).count }
    var canStart: Bool { readyCount >= 2 && screen == .lobby }
    var presenterLocale: String { presenterPacks.locale }
    var presenterLocales: [String] { OfflinePresenterPack.supportedLocales }

    func selectPresenterLocale(_ locale: String) {
        guard screen == .lobby else { return }
        presenterPacks.selectLocale(locale)
        presenterEngine.lineBook = presenterPacks.book
        objectWillChange.send()
        syncPresenterPack(force: true)
    }

    func selectPresenterOutputMode(_ mode: PresenterOutputMode) {
        guard screen == .lobby else { return }
        presenterOutputMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "presenter.output")
    }

    func selectPresenterIntensity(_ intensity: PresenterIntensity) {
        guard screen == .lobby, presenterOutputMode != .off else { return }
        presenterIntensity = intensity
        presenterEngine.intensity = intensity
        UserDefaults.standard.set(intensity.rawValue, forKey: "presenter.intensity")
    }

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
        let rawHostName = ProcessInfo.processInfo.hostName
        advertisedDeviceName = rawHostName
            .replacingOccurrences(of: ".local", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "-", with: " ")
        host = RoomHost(
            hostName: "ARE YOU STUPID?!",
            roomCode: code,
            clock: SystemHostClock(),
            judge: RoundDurationProvider()
        )
        presenterAudio = PresenterAudioController(packs: presenterPacks)
        let legacyMode = UserDefaults.standard.string(forKey: "presenter.mode")
        presenterOutputMode = PresenterOutputMode(rawValue: UserDefaults.standard.string(forKey: "presenter.output") ?? "")
            ?? (legacyMode == "off" ? .off : legacyMode == "mute" ? .mute : .voice)
        presenterIntensity = PresenterIntensity(rawValue: UserDefaults.standard.string(forKey: "presenter.intensity") ?? "")
            ?? (legacyMode == "neutral" ? .neutral : .savage)
        presenterEngine.intensity = presenterIntensity
        presenterEngine.lineBook = presenterPacks.book
        host.onBroadcast = { [weak self] message in
            Task { @MainActor in self?.handle(message) }
        }
    }

    /// Pulls the latest published presenter pack in the background. A new
    /// book is applied immediately in the lobby, otherwise at the next match
    /// start, so copy never changes mid-match.
    private func syncPresenterPack(force: Bool = false) {
        Task { [weak self] in
            guard let self, await self.presenterPacks.sync(force: force), self.screen == .lobby else { return }
            self.presenterEngine.lineBook = self.presenterPacks.book
        }
    }

    func startHosting() async {
        syncPresenterPack()
        server.onNewTransport = { [weak self] transport in
            self?.host.attachClient(transport)
        }
        do {
            let port = try await server.start(advertising: advertisement(state: "lobby"))
            directHostHint = QRGenerator.hostHint(address: LocalAddress.primaryIPv4(), port: port)
            networkStatus = "READY TO PARTY"
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
        challengeIdByRound = [:]
        lastAiCommentary = nil
        presenterEngine.lineBook = presenterPacks.book
        presenterEngine.beginMatch()
        syncPresenterPack()
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
        if let cgImage = QRGenerator.joinCode(roomCode: roomCode, hostHint: directHostHint) {
            return Image(decorative: cgImage, scale: 1, orientation: .up)
        }
        return Image(systemName: "qrcode")
    }

    var joinDeepLink: String { QRGenerator.joinDeepLink(roomCode: roomCode, hostHint: directHostHint) }

    private func advertisement(state: String) -> BonjourService {
        BonjourService(
            roomCode: roomCode,
            displayName: advertisedDeviceName,
            playerCount: roster.count,
            maxPlayers: maxPlayers,
            state: state
        )
    }

    private func refreshAdvertisement(state: String? = nil) {
        let currentState: String
        if let state {
            currentState = state
        } else if case .lobby = screen {
            currentState = "lobby"
        } else {
            currentState = "playing"
        }
        server.updateAdvertising(advertisement(state: currentState))
    }

    private func handle(_ message: any PartyMessage) {
        switch message {
        case let m as PlayerReadyRoster:
            roster = m.players
            announceReturningPlayers(m.players)
            refreshAdvertisement()
        case let m as RoomPerks:
            let justUnlockedPartyPack = !partyPackActive && m.partyPackActive
            maxPlayers = m.maxPlayers
            partyPackActive = m.partyPackActive
            if justUnlockedPartyPack { soundEffects.play(.partyPack) }
            refreshAdvertisement()
        case let m as AdBreakStarted:
            adBreakPlayerName = name(for: m.playerId)
        case is RematchReady:
            adBreakPlayerName = nil
            rematch()
        case let m as RoundStart:
            soundEffects.play(.roundStart)
            challengeIdByRound[m.roundId] = m.challengeId
            screen = .round(roundId: m.roundId)
            countdownState = nil
            lastAiCommentary = nil
            refreshAdvertisement(state: "playing")
            scheduleAutoComplete(roundId: m.roundId, closesAt: m.startAt + m.durationMs)
        case let m as RoundCountdown:
            countdownState = m.state
        case let m as RoundResults:
            screen = .results(results: m.results, roundId: m.roundId)
            presentRoundResults(m)
            scheduleAutoAdvance(afterRoundId: m.roundId)
        case let m as PlayerScore:
            if let previousLives = standings[m.playerId]?.lives,
               let lives = m.lives, previousLives > 0, lives == 0 {
                soundEffects.play(.elimination)
            }
            standings[m.playerId] = m
        case let m as PlayerLeave:
            roster.removeAll { $0.playerId == m.playerId }
            refreshAdvertisement()
        case let m as GameEnd:
            soundEffects.play(.winner)
            screen = .gameEnd(m)
            let winner = roster.first(where: { $0.playerId == m.winnerId }).map(presenterPlayer)
            if let winnerId = m.winnerId {
                presenterEngine.crownWinner(winnerId)
                rememberCareer(playerId: winnerId)
            }
            for player in roster where player.playerId != m.winnerId { rememberCareer(playerId: player.playerId) }
            present(presenterEngine.gameEnd(winner: winner))
        case let m as AiDirectorAssignment:
            directorName = m.directorPeerId.map(name(for:))
        case let m as AiChallengeRound:
            screen = .round(roundId: m.roundId)
            countdownState = nil
            lastAiCommentary = nil
            refreshAdvertisement(state: "playing")
            scheduleAutoComplete(roundId: m.roundId, closesAt: m.startAt + m.durationMs)
        case let m as AiCommentary:
            lastAiCommentary = m.text
        default:
            break
        }
    }

    private func presenterPlayer(_ player: PlayerInfo) -> PresenterPlayer {
        PresenterPlayer(id: player.playerId, displayName: player.playerName, spokenName: player.spokenName)
    }

    private func announceReturningPlayers(_ players: [PlayerInfo]) {
        guard screen == .lobby else { return }
        for player in players {
            guard let personaId = player.personaId,
                  announcedPersonas.insert(personaId).inserted,
                  let career = presenterCareers.career(for: personaId) else { continue }
            present(presenterEngine.returningCue(player: presenterPlayer(player), title: career.title))
        }
    }

    private func rememberCareer(playerId: String) {
        guard let player = roster.first(where: { $0.playerId == playerId }),
              let personaId = player.personaId,
              let title = presenterEngine.currentTitle(for: playerId) else { return }
        presenterCareers.remember(personaId: personaId, title: title)
    }

    private func presentRoundResults(_ results: RoundResults) {
        let remainingLives = Dictionary(uniqueKeysWithValues: results.results.compactMap { result -> (String, Int)? in
            guard selectedMode == .lastStupidStanding,
                  let previous = standings[result.playerId]?.lives else { return nil }
            return (result.playerId, max(0, previous - (result.correct ? 0 : 1)))
        })
        let fact = PresenterRoundFact(
            roundId: results.roundId,
            correctPlayerIds: results.results.filter(\.correct).map(\.playerId),
            wrongPlayerIds: results.results.filter { !$0.correct }.map(\.playerId),
            challengeId: challengeIdByRound.removeValue(forKey: results.roundId),
            mode: selectedMode == .lastStupidStanding ? .lastStupidStanding : .battle,
            remainingLivesByPlayer: remainingLives
        )
        for cue in presenterEngine.roundResult(fact, players: roster.map(presenterPlayer)) {
            present(cue)
        }
    }

    private func present(_ cue: PresenterCue) {
        guard presenterOutputMode != .off else { return }
        if presenterOutputMode == .mute {
            guard isRelevant(cue) else { return }
            lastAiCommentary = cue.text
            return
        }
        presenterAudio.play(cue, intensity: presenterEngine.intensity, stillRelevant: { [weak self] in
            self?.isRelevant(cue) == true
        }, onPlayback: { [weak self] in
            self?.lastAiCommentary = cue.text
        })
    }

    private func isRelevant(_ cue: PresenterCue) -> Bool {
        switch cue.expiry {
        case .whileLobby:
            return screen == .lobby
        case .throughResults(let roundId), .beforeNextRound(let roundId):
            guard case .results(_, let current) = screen else { return false }
            return current == roundId
        case .whileFactIsTrue:
            if case .results = screen { return true }
            return false
        case .whileGameEnd:
            if case .gameEnd = screen { return true }
            return false
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
        refreshAdvertisement(state: "lobby")
    }
}
