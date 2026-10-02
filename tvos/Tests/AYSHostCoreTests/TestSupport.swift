//
//  TestSupport.swift
//  AYSHostCoreTests
//
//  Shared doubles for the RoomHost suites — the Swift-side equivalent of
//  test/multiplayer/support/sim.dart's SimClient.
//

import AYSHostCore
import AYSProtocol

/// Resolves a duration (and rejects a configured set of unknown ids) —
/// `RoomHost` no longer needs anything more from a judge; content judging
/// moved to the client (see the design-change note on `PlayerAction` in
/// `lib/multiplayer/protocol/protocol.dart`), so `SimClient.tap`/
/// `commitCount` take an explicit `correct:` instead of this type deriving
/// it.
final class FakeChallengeJudge: ChallengeJudge {
    var durationMs: Int
    private let unknownIds: Set<String>

    init(durationMs: Int = 3000, unknownIds: Set<String> = []) {
        self.durationMs = durationMs
        self.unknownIds = unknownIds
    }

    func spec(challengeId: String, seed: Int, level: Int) -> ChallengeSpec? {
        if unknownIds.contains(challengeId) { return nil }
        return ChallengeSpec(challengeId: challengeId, seed: seed, level: level, durationMs: durationMs)
    }
}

/// One simulated phone: wraps a `HostTransport` end (in-memory for the
/// headless suites, a real `NWConnectionTransport` for `NetworkTests.swift`),
/// decodes every inbound line, and exposes small helpers for the client →
/// host messages.
final class SimClient {
    private let transport: HostTransport
    private(set) var received: [any PartyMessage] = []
    private(set) var lastPlayerJoined: PlayerJoined?
    private(set) var lastHostHello: HostHello?
    private(set) var lastRoster: [PlayerInfo] = []
    private(set) var lastRoundStart: RoundStart?
    private(set) var lastRoundResult: RoundResult?
    private(set) var lastError: PartyError?
    private(set) var lastRejected: Rejected?
    private(set) var lastGameEnd: GameEnd?
    private(set) var doneCount = 0
    private(set) var lastDirectorAssignment: AiDirectorAssignment?
    private(set) var lastAiChallengeRound: AiChallengeRound?
    private(set) var lastAiCommentary: AiCommentary?

    var selfId: String { lastPlayerJoined?.selfClientId ?? "" }

    init(transport: HostTransport) {
        self.transport = transport
        transport.onLine = { [weak self] line in self?.onLine(line) }
        transport.onDone = { [weak self] in self?.doneCount += 1 }
    }

    private func onLine(_ line: String) {
        guard case .ok(let message) = PartyProtocol.decode(line) else { return }
        received.append(message)
        switch message {
        case let m as PlayerJoined: lastPlayerJoined = m
        case let m as HostHello: lastHostHello = m
        case let m as PlayerReadyRoster: lastRoster = m.players
        case let m as RoundStart: lastRoundStart = m
        case let m as RoundResult: lastRoundResult = m
        case let m as PartyError: lastError = m
        case let m as Rejected: lastRejected = m
        case let m as GameEnd: lastGameEnd = m
        case let m as AiDirectorAssignment: lastDirectorAssignment = m
        case let m as AiChallengeRound: lastAiChallengeRound = m
        case let m as AiCommentary: lastAiCommentary = m
        default: break
        }
    }

    func hello(appVersion: String = "1.0") {
        transport.send((try? PartyProtocol.encode(Hello(appName: "test", appVersion: appVersion))) ?? "")
    }

    /// Sends a raw HELLO with an explicit protocolVersion, bypassing the
    /// Swift model (which always stamps the current version) so the
    /// mismatch gatekeeper path can be exercised.
    func helloWithProtocolVersion(_ version: Int) {
        transport.send(#"{"protocolVersion":\#(version),"type":"HELLO","ts":0,"appName":"test","appVersion":"1.0"}"#)
    }

    func join(name: String, emoji: String = "🟢") {
        transport.send((try? PartyProtocol.encode(JoinRoom(playerName: name, emoji: emoji))) ?? "")
    }

    func ready(_ ready: Bool = true) {
        transport.send((try? PartyProtocol.encode(PlayerReady(playerId: selfId, ready: ready))) ?? "")
    }

    func leave() {
        transport.send((try? PartyProtocol.encode(LeaveRoom())) ?? "")
    }

    /// [correct] stands in for what a real phone's `PartyChallengeRunner`
    /// would have computed locally — `RoomHost` no longer judges content
    /// (see the design-change note on `PlayerAction` in
    /// `lib/multiplayer/protocol/protocol.dart`), so this test double must
    /// supply the verdict itself instead of relying on a judge to derive it.
    func tap(_ targetId: String?, roundId: String, correct: Bool) {
        transport.send((try? PartyProtocol.encode(PlayerAction(
            playerId: selfId, roundId: roundId, action: .tap(targetId: targetId), correct: correct
        ))) ?? "")
    }

    func commitCount(_ n: Int, roundId: String, correct: Bool) {
        transport.send((try? PartyProtocol.encode(PlayerAction(
            playerId: selfId, roundId: roundId, action: .count(n), correct: correct
        ))) ?? "")
    }

    func sendRaw(_ line: String) {
        transport.send(line)
    }

    /// AI Director wire kinds (Phase 7 — [[Multiplayer AI Director]]).
    func sendAiCapabilities(aiAvailable: Bool, computeRank: Int = 0, batteryPercent: Int = 100) {
        transport.send((try? PartyProtocol.encode(AiCapabilities(
            aiAvailable: aiAvailable, computeRank: computeRank, batteryPercent: batteryPercent
        ))) ?? "")
    }

    func sendAiRoundProposal(roundId: String, proposal: [String: Any] = ["id": "ai.abc12"]) {
        transport.send((try? PartyProtocol.encode(AiRoundProposal(
            roundId: roundId, proposal: proposal
        ))) ?? "")
    }

    func sendAiCommentaryProposal(kind: String, roundId: String, text: String) {
        transport.send((try? PartyProtocol.encode(AiCommentaryProposal(
            kind: kind, roundId: roundId, text: text
        ))) ?? "")
    }

    func disconnect() {
        transport.close()
    }
}

/// Wires a `RoomHost` + N `SimClient`s over `InMemoryHostTransport` pairs,
/// joined and readied in one call for the common case.
///
/// `RoomHost` only weak-captures itself internally (see `attachClient`), so
/// discarding the returned `host` (`let (_, clients) = makeHarness(...)`)
/// lets it deallocate immediately — every subsequent message then goes
/// nowhere, silently, no error. Always bind `host` and keep it in scope
/// (`withExtendedLifetime` if a test never reads it directly).
func makeHarness(
    playerCount: Int,
    clock: ManualHostClock = ManualHostClock(1000),
    judge: ChallengeJudge = FakeChallengeJudge(),
    maxPlayers: Int = 8,
    lives: Int = 3,
    battleRounds: Int = 20,
    speedBonus: Bool = false,
    graceWindowMs: Int = 15000
) -> (host: RoomHost, clients: [SimClient]) {
    let host = RoomHost(
        maxPlayers: maxPlayers,
        lives: lives,
        battleRounds: battleRounds,
        speedBonus: speedBonus,
        graceWindowMs: graceWindowMs,
        clock: clock,
        judge: judge
    )
    var clients: [SimClient] = []
    for i in 0..<playerCount {
        let (hostSide, clientSide) = InMemoryHostTransport.pair()
        host.attachClient(hostSide)
        let client = SimClient(transport: clientSide)
        client.hello()
        client.join(name: "Player\(i)")
        clients.append(client)
    }
    return (host, clients)
}
