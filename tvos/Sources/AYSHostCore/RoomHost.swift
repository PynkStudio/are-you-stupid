//
//  RoomHost.swift
//  AYSHostCore
//
//  The authoritative Swift host: room lifecycle, roster, ready-gating,
//  round timing/broadcast, action validation, scoring, elimination and
//  GAME_END — a faithful port of test/support/party_host_reference.dart,
//  the same rules every Phase 2 Dart suite proves correct. Challenge
//  content (rebuilding the canonical challenge, judging a tap) is NOT here:
//  it's injected via ChallengeJudge.swift, the seam that keeps this class
//  buildable and testable independent of Phase 4's open PRNG-parity
//  question (docs/Gameplay/Multiplayer Challenges.md, docs/Meta/Decision
//  Log.md).
//
//  Pure Swift Foundation only: no Network.framework, no SwiftUI. Real
//  sockets/Bonjour (Net/) and the SwiftUI board (UI/) are separate, still to
//  come — see docs/Architecture/Multiplayer Host (tvOS).md.
//

import AYSProtocol
import Foundation

public enum RoomHostError: Error, CustomStringConvertible, Equatable {
    case notEnoughReadyPlayers(Int)
    case unknownChallenge(String)

    public var description: String {
        switch self {
        case .notEnoughReadyPlayers(let n):
            return "need >= 2 ready players to start (got \(n))"
        case .unknownChallenge(let id):
            return "unknown challengeId: \(id)"
        }
    }
}

public final class RoomHost {
    public init(
        hostName: String = "ARE YOU STUPID?",
        roomCode: String = "AYS",
        maxPlayers: Int = 8,
        lives: Int = 3,
        battleRounds: Int = 20,
        speedBonus: Bool = false,
        graceWindowMs: Int = 15000,
        clock: HostClock,
        judge: ChallengeJudge,
        picker: ChallengePicker = WeightedChallengePicker()
    ) {
        self.hostName = hostName
        self.roomCode = roomCode
        self.maxPlayers = maxPlayers
        self.lives = lives
        self.battleRounds = battleRounds
        self.speedBonus = speedBonus
        self.graceWindowMs = graceWindowMs
        self.clock = clock
        self.judge = judge
        self.picker = picker
    }

    public let hostName: String
    public let roomCode: String
    public let maxPlayers: Int
    public let lives: Int
    public let battleRounds: Int
    public let speedBonus: Bool
    public let graceWindowMs: Int

    private let clock: HostClock
    private let judge: ChallengeJudge
    private let picker: ChallengePicker

    private var conns: [Connection] = []
    private var seats: [String: Seat] = [:]
    private var joinOrder: [String] = []
    private var nextPlayer = 0
    private var nextRound = 0
    private var mode: GameMode = .stupidBattle
    private var inGame = false
    private var roundIndex = 0
    private var round: RoundState?
    private var lastChallengeId: String?

    // MARK: AI Director (Phase 8 — [[Multiplayer AI Director]])

    private var directorPeerId: String?

    /// The Director's most recently sent, not-yet-consumed round proposal.
    /// A single slot, not a queue — mirrors [[Pre-generation Cache]]'s "the
    /// host never waits" contract without a background fetch of its own
    /// (generation happens on a different device entirely): if nothing is
    /// here when the next round needs to start, `startNextRound` falls back
    /// to the scripted picker, silently, exactly like a cache underflow.
    private var pendingAiProposal: (roundId: String, proposal: [String: Any])?

    public var currentDirectorPeerId: String? { directorPeerId }

    /// Fires with every message this host broadcasts to all clients — the
    /// same events a connected phone sees, so a local UI (the App/UI board
    /// itself) can stay in sync without attaching a fake loopback client.
    /// Never fires for a message sent to a single connection (reconnect
    /// snapshots, per-seat `RoundResult`), only broadcasts.
    public var onBroadcast: ((any PartyMessage) -> Void)?

    public var nowMs: Int { clock.nowMs }
    public var seatCount: Int { seats.count }
    public var aliveCount: Int { seats.values.filter(\.alive).count }
    public var roundOpen: Bool { round.map { !$0.ended } ?? false }

    /// The capability a seat last announced via `AI_CAPABILITIES`, or `nil`
    /// if it never has. Phase 7 plumbing only — read by the Phase 8
    /// Director election, and by tests until then.
    public func aiCapabilities(for playerId: String) -> AiCapabilities? {
        seats[playerId]?.aiCapabilities
    }
    public var openRoundId: String? { round?.id }
    public var isInGame: Bool { inGame }

    // MARK: - Connections

    /// Registers a transport as a client connection. The connection is
    /// greeted when it sends HELLO.
    public func attachClient(_ transport: HostTransport) {
        let conn = Connection(transport: transport)
        // `self` is weak so RoomHost is never kept alive by its own
        // connections — whoever owns the match must hold a strong
        // reference to the RoomHost itself for as long as it's in use;
        // that's not optional, and letting it go early means every inbound
        // message on every connection silently goes nowhere.
        //
        // `conn`, in contrast, is captured STRONGLY: its only job is to
        // exist for exactly as long as its own transport's closures do,
        // independent of whatever else is or isn't still holding it (an
        // earlier version weak-captured `conn` too, relying solely on
        // `self.conns` — functionally correct, but coupled `conn`'s
        // lifetime to bookkeeping it has no real reason to depend on). The
        // resulting cycle (conn -> transport -> closure -> conn) is broken
        // explicitly in `detach(_:)` below once the connection ends.
        transport.onLine = { [weak self] line in
            self?.onLine(conn, line)
        }
        transport.onDone = { [weak self] in
            self?.onDisconnected(conn)
        }
        conns.append(conn)
    }

    /// Breaks the `conn` retain cycle `attachClient` creates. Always call
    /// this once a connection is done with, whether it left cleanly or the
    /// transport just closed.
    private func detach(_ conn: Connection) {
        conn.transport.onLine = nil
        conn.transport.onDone = nil
    }

    public func close() {
        for conn in conns {
            conn.transport.close()
            detach(conn)
        }
    }

    // MARK: - Gatekeeper

    private func onLine(_ conn: Connection, _ line: String) {
        var incomingVersion: Int?
        if let data = line.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            incomingVersion = obj["protocolVersion"] as? Int
        }

        switch PartyProtocol.decode(line) {
        case .ok(let message):
            if message is Hello, let v = incomingVersion, v != kProtocolVersion {
                send(conn, Rejected(
                    reason: "protocolVersion \(v) unsupported, need \(kProtocolVersion)",
                    ts: nowMs
                ))
                return
            }
            handle(conn, message)
        case .malformed:
            send(conn, PartyError(code: "BAD_MESSAGE", detail: "malformed frame", ts: nowMs))
        case .unknownType:
            break // forward-tolerant.
        }
    }

    private func handle(_ conn: Connection, _ message: any PartyMessage) {
        switch message {
        case is Hello:
            onHello(conn)
        case let m as JoinRoom:
            onJoin(conn, m)
        case let m as PlayerReady:
            onReady(conn, m)
        case is LeaveRoom:
            onLeave(conn)
        case let m as PlayerAction:
            onAction(conn, m)
        case let m as AiCapabilities:
            onAiCapabilities(conn, m)
        case let m as AiRoundProposal:
            onAiRoundProposal(conn, m)
        case let m as AiCommentaryProposal:
            onAiCommentaryProposal(conn, m)
        default:
            send(conn, PartyError(code: "BAD_MESSAGE", detail: "unexpected \(message.type)", ts: nowMs))
        }
    }

    /// Remembers a seat's on-device model capability for the Director
    /// election. Doesn't re-elect on its own — the election only runs at
    /// `startGame()` and on a Director's departure, so an in-match
    /// capability announcement (a late joiner) takes effect next match.
    private func onAiCapabilities(_ conn: Connection, _ capabilities: AiCapabilities) {
        guard let seat = seatFor(conn) else { return }
        seat.aiCapabilities = capabilities
    }

    /// Accepts a validated round from the elected Director only — anyone
    /// else's proposal is silently ignored, the same trust boundary
    /// `AI_CAPABILITIES`-based election exists to establish. Queued, not
    /// applied immediately: `startNextRound` consumes it when the match
    /// actually needs a new round.
    private func onAiRoundProposal(_ conn: Connection, _ proposal: AiRoundProposal) {
        guard let seat = seatFor(conn), seat.playerId == directorPeerId else { return }
        pendingAiProposal = (roundId: proposal.roundId, proposal: proposal.proposal)
    }

    /// Relays the Director's commentary line as-is, immediately (unlike a
    /// round proposal, there's no "next round" moment to wait for).
    private func onAiCommentaryProposal(_ conn: Connection, _ proposal: AiCommentaryProposal) {
        guard let seat = seatFor(conn), seat.playerId == directorPeerId else { return }
        broadcast(AiCommentary(kind: proposal.kind, roundId: proposal.roundId, text: proposal.text, ts: nowMs))
    }

    private func onHello(_ conn: Connection) {
        send(conn, HostHello(hostName: hostName, roomCode: roomCode, maxPlayers: maxPlayers, ts: nowMs))
    }

    private func onJoin(_ conn: Connection, _ join: JoinRoom) {
        if inGame {
            tryReconnect(conn, join)
            return
        }
        if seats.count >= maxPlayers {
            send(conn, PartyError(code: "ROOM_FULL", detail: "host is full", ts: nowMs))
            return
        }
        let seat = Seat(
            playerId: "p\(nextPlayer)",
            gameName: join.playerName,
            emoji: join.emoji,
            joinOrder: joinOrder.count,
            lives: lives
        )
        nextPlayer += 1
        seat.conn = conn
        seats[seat.playerId] = seat
        joinOrder.append(seat.playerId)
        send(conn, joined(seat))
        broadcastRoster()
    }

    private func tryReconnect(_ conn: Connection, _ join: JoinRoom) {
        let candidate = seats.values.first {
            $0.alive && $0.conn == nil && $0.gameName == join.playerName && $0.emoji == join.emoji
        }
        guard let candidate else {
            rejectReconnect(conn, join)
            return
        }
        let since = nowMs - (candidate.disconnectedAtMs ?? nowMs)
        if since > graceWindowMs {
            rejectReconnect(conn, join)
            return
        }
        candidate.conn = conn
        candidate.disconnectedAtMs = nil
        // Re-introduce the session to itself: same playerId + roster it had
        // before the drop, so the phone knows who it is again.
        send(conn, joined(candidate))
        broadcastRoster()
        broadcast(PlayerReconnected(playerId: candidate.playerId, ts: nowMs))
    }

    private func rejectReconnect(_ conn: Connection, _ join: JoinRoom) {
        send(conn, PartyError(
            code: "ROOM_FULL",
            detail: "no reconnectable seat for \(join.playerName)",
            ts: nowMs
        ))
    }

    private func onReady(_ conn: Connection, _ ready: PlayerReady) {
        guard let seat = seatFor(conn) else { return }
        if !ready.playerId.isEmpty && ready.playerId != seat.playerId {
            send(conn, PartyError(code: "BAD_MESSAGE", detail: "wrong playerId", ts: nowMs))
            return
        }
        seat.ready = ready.ready
        broadcastRoster()
    }

    private func onLeave(_ conn: Connection) {
        guard let seat = seatFor(conn) else { return }
        removeSeat(seat, reason: "left")
    }

    // MARK: - Rounds

    /// Starts a match. Requires >= 2 ready players (the protocol gate).
    public func startGame(mode: GameMode = .stupidBattle) throws {
        if inGame { return }
        let readyCount = seats.values.filter(\.ready).count
        guard readyCount >= 2 else { throw RoomHostError.notEnoughReadyPlayers(readyCount) }

        for seat in seats.values {
            seat.ready = false
            seat.alive = true
            seat.score = 0
            seat.lives = lives
            seat.pendingAction = nil
            seat.actionElapsedMs = nil
        }
        self.mode = mode
        inGame = true
        roundIndex = 0

        var config: [String: Any] = [:]
        if mode == .lastStupidStanding { config["lives"] = lives }
        if mode == .stupidBattle { config["totalRounds"] = battleRounds }
        if speedBonus { config["speedBonus"] = true }
        broadcast(StartGame(mode: mode, config: config, ts: nowMs))

        electDirector()
    }

    /// Opens a round for an explicit tuple (deterministic for tests).
    public func startRound(challengeId: String, seed: Int, level: Int) throws {
        pruneDisconnected()
        guard let spec = judge.spec(challengeId: challengeId, seed: seed, level: level) else {
            throw RoomHostError.unknownChallenge(challengeId)
        }
        let startAt = nowMs
        let r = RoundState(id: "r\(nextRound)", spec: spec, startAt: startAt)
        nextRound += 1
        round = r
        roundIndex += 1

        broadcast(RoundStart(
            roundId: r.id,
            challengeId: challengeId,
            seed: seed,
            startAt: startAt,
            durationMs: spec.durationMs,
            config: ["level": level],
            ts: nowMs
        ))
        broadcast(RoundCountdown(roundId: r.id, atMs: startAt - 1000, state: "READY", ts: nowMs))
        broadcast(RoundCountdown(roundId: r.id, atMs: startAt, state: "GO", ts: nowMs))

        for seat in seats.values where seat.alive {
            seat.pendingAction = nil
            seat.actionElapsedMs = nil
        }
    }

    /// Picks a round like the solo generator and opens it (level-gated,
    /// weighted, no immediate repeat — see ChallengePicker.swift).
    public func startRandomRound(level: Int) throws {
        let challengeId = picker.pick(level: level, lastId: lastChallengeId)
        lastChallengeId = challengeId
        let seed = nowMs & 0x7fffffff
        try startRound(challengeId: challengeId, seed: seed, level: level)
    }

    /// Opens the next round from the elected Director's pending proposal
    /// when one is ready, otherwise the scripted picker — the production
    /// entry point `HostViewModel` calls instead of `startRandomRound`
    /// directly, so a match with no AI Director (or one that hasn't sent
    /// anything yet) plays identically to today.
    public func startNextRound(level: Int) throws {
        if let pending = pendingAiProposal {
            pendingAiProposal = nil
            try startAiRound(proposal: pending.proposal, level: level)
            return
        }
        try startRandomRound(level: level)
    }

    /// Opens a round from an AI-authored proposal, relayed **as-is** — the
    /// host does not re-validate it (no `ChallengeValidator`/registry on
    /// this side; see [[Multiplayer AI Director]] and the design-change
    /// note on `PlayerAction` this mirrors). `ChallengeSpec.challengeId`/
    /// `.seed` are placeholders (`"ai"`/`0`) since nothing downstream reads
    /// them for an AI round — only `.durationMs` matters, for the
    /// force-timeout deadline in `completeRound()`.
    public func startAiRound(proposal: [String: Any], level: Int) throws {
        pruneDisconnected()
        let difficulty = proposal["difficulty"] as? [String: Any]
        let durationMs = difficulty?["timeLimitMs"] as? Int ?? 6000
        let spec = ChallengeSpec(challengeId: "ai", seed: 0, level: level, durationMs: durationMs)
        let startAt = nowMs
        let r = RoundState(id: "r\(nextRound)", spec: spec, startAt: startAt)
        nextRound += 1
        round = r
        roundIndex += 1

        broadcast(AiChallengeRound(
            roundId: r.id,
            proposal: proposal,
            startAt: startAt,
            durationMs: durationMs,
            ts: nowMs
        ))
        broadcast(RoundCountdown(roundId: r.id, atMs: startAt - 1000, state: "READY", ts: nowMs))
        broadcast(RoundCountdown(roundId: r.id, atMs: startAt, state: "GO", ts: nowMs))

        for seat in seats.values where seat.alive {
            seat.pendingAction = nil
            seat.actionElapsedMs = nil
        }
    }

    /// Picks a Director among seats that announced `AI_CAPABILITIES` with
    /// `aiAvailable == true`: highest `computeRank` wins, ties broken by
    /// the lexicographically smaller `playerId` (a stable, arbitrary but
    /// deterministic tie-break — see the Decision Log on why a finer
    /// battery-based tie-break isn't worth a new dependency). Broadcasts
    /// the result — including `nil`, when no seat is capable — only when
    /// it actually changes, so a reconnect within the grace window doesn't
    /// cause a spurious reassignment flicker.
    private func electDirector() {
        var winner: Seat?
        for seat in seats.values {
            guard let cap = seat.aiCapabilities, cap.aiAvailable else { continue }
            guard let current = winner, let currentCap = current.aiCapabilities else {
                winner = seat
                continue
            }
            if cap.computeRank > currentCap.computeRank ||
                (cap.computeRank == currentCap.computeRank && seat.playerId < current.playerId) {
                winner = seat
            }
        }
        let newDirectorId = winner?.playerId
        guard newDirectorId != directorPeerId else { return }
        directorPeerId = newDirectorId
        pendingAiProposal = nil
        broadcast(AiDirectorAssignment(directorPeerId: newDirectorId, ts: nowMs))
    }

    /// Re-runs the election when the departing seat was the Director —
    /// called only once a seat is actually removed (not on a mere
    /// disconnect still inside the reconnect grace window), so a Director
    /// that reconnects in time keeps its assignment instead of losing and
    /// immediately regaining it.
    private func reelectIfDirectorLeft(_ playerId: String) {
        guard playerId == directorPeerId else { return }
        electDirector()
    }

    /// Closes the open round: times out anything unanswered, then
    /// broadcasts ROUND_RESULTS, score patches, ROUND_END and — when the
    /// match is decided — GAME_END.
    public func completeRound() {
        guard let r = round, !r.ended else { return }
        r.ended = true

        for seat in seats.values where seat.alive {
            if r.judged(for: seat.playerId) != nil { continue }
            // A functioning client self-reports its own timeout verdict
            // before going silent (`PartyChallengeRunner`'s `tick` fires
            // `onTimeout` locally and sends the result, same as a tap) —
            // see the design-change note on `PlayerAction`. This fallback
            // only ever fires for a seat that's genuinely gone quiet
            // (disconnected, crashed), for which "wrong" is the only
            // reasonable default: the host has no way left to know what the
            // real outcome would have been.
            let verdict = JudgeVerdict(correct: false, reason: "too slow")
            let result = self.result(seat, verdict, actionElapsedMs: nil)
            r.setJudged(seat.playerId, result)
            if let conn = seat.conn {
                send(conn, RoundResult(
                    roundId: r.id,
                    correct: result.correct,
                    reason: result.reason,
                    scoreDelta: result.scoreDelta,
                    actionReceivedMs: nil,
                    ts: nowMs
                ))
            }
        }

        broadcast(RoundResults(roundId: r.id, results: r.judgedValuesInOrder, ts: nowMs))
        broadcast(RoundEnd(roundId: r.id, ts: nowMs))

        applyScoring(r)
        endRoundIfDecided()
    }

    private func onAction(_ conn: Connection, _ action: PlayerAction) {
        guard let r = round, !r.ended else {
            send(conn, PartyError(code: "ROUND_CLOSED", detail: "no open round", ts: nowMs))
            return
        }
        guard let seat = seatFor(conn), seat.playerId == action.playerId else {
            send(conn, PartyError(code: "BAD_MESSAGE", detail: "unknown playerId", ts: nowMs))
            return
        }
        guard seat.alive else { return } // eliminated seats are spectators.
        guard action.roundId == r.id else {
            send(conn, PartyError(code: "ROUND_CLOSED", detail: "stale round", ts: nowMs))
            return
        }
        guard seat.pendingAction == nil else {
            send(conn, PartyError(code: "DUPLICATE_ACTION", detail: "already submitted", ts: nowMs))
            return
        }

        let elapsed = nowMs - r.startAt
        guard elapsed < r.spec.durationMs else {
            send(conn, PartyError(code: "ROUND_CLOSED", detail: "round expired", ts: nowMs))
            return
        }

        // The host no longer re-judges — it trusts the client's own verdict,
        // computed by `PartyChallengeRunner` (the same engine single-player
        // uses). See the design-change note on `PlayerAction`.
        let verdict = JudgeVerdict(correct: action.correct, note: action.note, reason: action.reason)
        seat.pendingAction = action.action
        seat.actionElapsedMs = elapsed
        let result = self.result(seat, verdict, actionElapsedMs: elapsed)
        r.setJudged(seat.playerId, result)
        send(conn, RoundResult(
            roundId: r.id,
            correct: result.correct,
            reason: result.reason,
            scoreDelta: result.scoreDelta,
            actionReceivedMs: nowMs,
            ts: nowMs
        ))

        // "No downtime" (docs/Gameplay/Game Design Pillars.md): don't make
        // everyone wait out the full timer once the last alive player has
        // answered. Every entry in `judgedOrder` at this point came from a
        // real `PLAYER_ACTION` (only alive seats can reach this far — see
        // the `seat.alive` guard above), so comparing its count to
        // `aliveCount` is exactly "has every alive seat submitted."
        // `completeRound()` is safe to call here even though the round
        // hasn't timed out yet: every alive seat is already judged, so its
        // own timeout-judging loop finds nothing left to do.
        if r.judgedOrder.count >= aliveCount {
            completeRound()
        }
    }

    // MARK: - Judging glue

    private func result(_ seat: Seat, _ verdict: JudgeVerdict, actionElapsedMs: Int?) -> PlayerRoundResult {
        var scoreDelta = 0
        if verdict.correct && mode == .stupidBattle { scoreDelta = 100 }
        return PlayerRoundResult(
            playerId: seat.playerId,
            correct: verdict.correct,
            reason: verdict.correct ? (verdict.note ?? "") : (verdict.reason ?? ""),
            scoreDelta: scoreDelta,
            reactionMs: actionElapsedMs
        )
    }

    // MARK: - Scoring

    private func applyScoring(_ r: RoundState) {
        if mode == .lastStupidStanding {
            for seat in seats.values where seat.alive {
                if let res = r.judged(for: seat.playerId), !res.correct {
                    seat.lives -= 1
                    if seat.lives <= 0 {
                        seat.alive = false
                        broadcast(PlayerEliminated(roundId: r.id, playerId: seat.playerId, ts: nowMs))
                    }
                }
                broadcast(PlayerScore(
                    playerId: seat.playerId,
                    mode: mode,
                    score: seat.score,
                    lives: seat.lives,
                    standing: standing(for: seat),
                    ts: nowMs
                ))
            }
            return
        }

        // Battle: point deltas + optional top-3 reaction bonus.
        let bonus = [50, 25, 10]
        for (i, playerId) in correctOrder(r).enumerated() {
            guard let seat = seats[playerId] else { continue }
            var delta = 100
            if speedBonus && i < bonus.count { delta += bonus[i] }
            seat.score += delta
        }
        for seat in seats.values {
            broadcast(PlayerScore(
                playerId: seat.playerId,
                mode: mode,
                score: seat.score,
                standing: standing(for: seat),
                ts: nowMs
            ))
        }
    }

    private func standings() -> [String] {
        joinOrder.sorted { a, b in
            let sa = seats[a]!.score
            let sb = seats[b]!.score
            if sa != sb { return sa > sb }
            return seats[a]!.joinOrder < seats[b]!.joinOrder
        }
    }

    private func standing(for seat: Seat) -> Int {
        (standings().firstIndex(of: seat.playerId) ?? -1) + 1
    }

    private func soleSurvivor() -> String? {
        seats.values.first(where: \.alive)?.playerId
    }

    /// Correct-answerers, fastest first. Ties (equal `reactionMs`, or both
    /// nil) keep arrival order — `judgedOrder` plus a stable sort, matching
    /// how Dart's insertion-ordered `Map` behaves for the same tie.
    private func correctOrder(_ r: RoundState) -> [String] {
        r.judgedOrder
            .filter { r.judged(for: $0)?.correct == true }
            .sorted { a, b in
                switch (r.judged(for: a)?.reactionMs, r.judged(for: b)?.reactionMs) {
                case let (ra?, rb?): return ra < rb
                case (nil, nil): return false
                case (nil, _): return false // nil sorts last.
                case (_, nil): return true
                }
            }
    }

    private func endRoundIfDecided() {
        guard inGame else { return }
        if mode == .lastStupidStanding {
            let alive = aliveCount
            if alive <= 1 {
                finish(winnerId: alive == 1 ? soleSurvivor() : nil)
            }
            return
        }
        if roundIndex >= battleRounds {
            finish(winnerId: standings().first)
        }
    }

    private func finish(winnerId: String?) {
        inGame = false
        let order = standings()
        let results = order.enumerated().map { i, playerId -> GameResultEntry in
            let seat = seats[playerId]!
            return GameResultEntry(
                playerId: playerId,
                score: seat.score,
                lives: mode == .lastStupidStanding ? seat.lives : nil,
                standing: i + 1
            )
        }
        broadcast(GameEnd(mode: mode, results: results, winnerId: winnerId, ts: nowMs))
    }

    // MARK: - Wiring

    private func pruneDisconnected() {
        guard inGame else { return }
        for seat in Array(seats.values) where seat.conn == nil && seat.alive {
            let since = nowMs - (seat.disconnectedAtMs ?? nowMs)
            if since > graceWindowMs {
                seat.alive = false
                removeSeat(seat, reason: "disconnected")
            }
        }
    }

    private func onDisconnected(_ conn: Connection) {
        guard let idx = conns.firstIndex(where: { $0 === conn }) else { return }
        conns.remove(at: idx)
        detach(conn)
        guard let seat = seatFor(conn) else { return } // unseated connection.
        if !inGame {
            removeSeat(seat, reason: "disconnected")
            return
        }
        seat.conn = nil
        seat.disconnectedAtMs = nowMs
        broadcast(PlayerDisconnected(playerId: seat.playerId, ts: nowMs))
        pruneDisconnected()
    }

    private func removeSeat(_ seat: Seat, reason: String) {
        seats.removeValue(forKey: seat.playerId)
        joinOrder.removeAll { $0 == seat.playerId }
        broadcast(PlayerLeave(playerId: seat.playerId, reason: reason, ts: nowMs))
        reelectIfDirectorLeft(seat.playerId)
    }

    private func broadcastRoster() {
        broadcast(PlayerReadyRoster(players: rosterSnapshot(), ts: nowMs))
    }

    private func info(_ seat: Seat) -> PlayerInfo {
        PlayerInfo(playerId: seat.playerId, playerName: seat.gameName, emoji: seat.emoji, ready: seat.ready)
    }

    /// Join order, not `seats.values`' unspecified Dictionary order — mirrors
    /// Dart's insertion-ordered `Map` so the roster displays in join order.
    private func rosterSnapshot() -> [PlayerInfo] {
        joinOrder.compactMap { seats[$0].map(info) }
    }

    private func joined(_ seat: Seat) -> PlayerJoined {
        PlayerJoined(selfClientId: seat.playerId, roomId: roomCode, players: rosterSnapshot())
    }

    private func seatFor(_ conn: Connection) -> Seat? {
        seats.values.first { $0.conn === conn }
    }

    private func broadcast(_ message: any PartyMessage) {
        guard let wire = try? PartyProtocol.encode(message) else { return }
        for conn in conns { conn.transport.send(wire) }
        onBroadcast?(message)
    }

    private func send(_ conn: Connection, _ message: any PartyMessage) {
        guard let wire = try? PartyProtocol.encode(message) else { return }
        conn.transport.send(wire)
    }
}

// MARK: - Private state

private final class Connection {
    let transport: HostTransport
    init(transport: HostTransport) { self.transport = transport }
}

private final class Seat {
    let playerId: String
    let gameName: String
    let emoji: String
    let joinOrder: Int
    var ready = false
    var alive = true
    var lives: Int
    var score = 0
    var conn: Connection?
    var disconnectedAtMs: Int?
    var pendingAction: PartyAction?
    var actionElapsedMs: Int?

    /// Set on `AI_CAPABILITIES` — `nil` until this seat announces itself.
    /// Phase 7 only stores this; the election that reads it is Phase 8.
    var aiCapabilities: AiCapabilities?

    init(playerId: String, gameName: String, emoji: String, joinOrder: Int, lives: Int) {
        self.playerId = playerId
        self.gameName = gameName
        self.emoji = emoji
        self.joinOrder = joinOrder
        self.lives = lives
    }
}

private final class RoundState {
    let id: String
    let spec: ChallengeSpec
    let startAt: Int
    var ended = false

    // Swift's Dictionary has no guaranteed iteration order (unlike Dart's
    // insertion-ordered Map), so judged results are tracked with an explicit
    // arrival-order list alongside the lookup table — RoomHost.correctOrder
    // relies on that order to break exact reactionMs ties the same way the
    // Dart reference does (first-to-answer wins).
    private(set) var judgedOrder: [String] = []
    private var judgedByPlayer: [String: PlayerRoundResult] = [:]

    init(id: String, spec: ChallengeSpec, startAt: Int) {
        self.id = id
        self.spec = spec
        self.startAt = startAt
    }

    func judged(for playerId: String) -> PlayerRoundResult? {
        judgedByPlayer[playerId]
    }

    func setJudged(_ playerId: String, _ result: PlayerRoundResult) {
        if judgedByPlayer[playerId] == nil { judgedOrder.append(playerId) }
        judgedByPlayer[playerId] = result
    }

    /// Arrival-order values — the Swift equivalent of Dart's `Map.values`.
    var judgedValuesInOrder: [PlayerRoundResult] {
        judgedOrder.compactMap { judgedByPlayer[$0] }
    }
}
