import Foundation

public enum PresenterIntensity: String, Codable, Sendable {
    case neutral
    case savage
}

public enum PresenterCueKind: String, Codable, Sendable {
    case lobby
    case roundResult
    case elimination
    case title
    case gameEnd
}

public enum PresenterExpiry: Equatable, Sendable {
    case whileLobby
    case throughResults(roundId: String)
    case beforeNextRound(roundId: String)
    case whileFactIsTrue(key: String)
    case whileGameEnd
}

public struct PresenterCue: Equatable, Sendable {
    public let id: String
    public let kind: PresenterCueKind
    public let text: String
    public let targetPlayerId: String?
    public let expiry: PresenterExpiry
    public let cacheable: Bool

    public init(id: String, kind: PresenterCueKind, text: String, targetPlayerId: String? = nil, expiry: PresenterExpiry, cacheable: Bool) {
        self.id = id
        self.kind = kind
        self.text = text
        self.targetPlayerId = targetPlayerId
        self.expiry = expiry
        self.cacheable = cacheable
    }
}

public struct PresenterPlayer: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let spokenName: String?

    public init(id: String, displayName: String, spokenName: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.spokenName = spokenName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

public struct PresenterRoundFact: Equatable, Sendable {
    public let roundId: String
    public let correctPlayerIds: [String]
    public let wrongPlayerIds: [String]

    public init(roundId: String, correctPlayerIds: [String], wrongPlayerIds: [String]) {
        self.roundId = roundId
        self.correctPlayerIds = correctPlayerIds
        self.wrongPlayerIds = wrongPlayerIds
    }
}

/// Versioned, text-side manifest for the baseline audio pack. Production
/// audio assets use these exact IDs; the text is also the subtitle and the
/// development TTS fallback, so the three surfaces cannot drift.
public enum OfflinePresenterPack {
    public static let version = 1
    public static let lines: [String: [String]] = [
        "lobby.empty": [
            "NESSUNO. PROMETTENTE.",
            "LA SERATA È GIÀ UN SUCCESSO.",
        ],
        "result.everyoneWrong": [
            "NESSUNO HA LETTO. PERFETTO.",
            "ZERO RISPOSTE GIUSTE. GRANDE SQUADRA.",
            "AVETE SBAGLIATO TUTTI. INSIEME.",
        ],
        "result.everyoneCorrect": [
            "SOSPETTOSAMENTE COMPETENTI.",
            "TUTTI GIUSTI. NON ABITUATEVI.",
        ],
        "result.mixed": [
            "ALCUNI HANNO LETTO. ALCUNI ERANO PRESENTI.",
            "RISULTATI MISTI. MOLTO MISTI.",
        ],
        "gameEnd": [
            "ABBIAMO UN VINCITORE. TECNICAMENTE.",
            "È FINITA. POTETE TORNARE A FINGERVI INTELLIGENTI.",
        ],
    ]
}

/// Pure presenter director. It consumes verified match facts only and emits
/// short cues; audio/network concerns live above it.
public final class PresenterEngine {
    public var intensity: PresenterIntensity
    private var recentLineIds: [String] = []
    private var wins: [String: Int] = [:]
    private var wrongStreak: [String: Int] = [:]
    private var titleByPlayer: [String: String] = [:]
    private var sequence = 0

    public init(intensity: PresenterIntensity = .neutral) {
        self.intensity = intensity
    }

    public func lobbyEmpty() -> PresenterCue {
        universal(key: "lobby.empty", kind: .lobby, expiry: .whileLobby)
    }

    public func roundResult(_ fact: PresenterRoundFact, players: [PresenterPlayer]) -> [PresenterCue] {
        for player in players {
            if fact.correctPlayerIds.contains(player.id) {
                wrongStreak[player.id] = 0
                wins[player.id, default: 0] += 1
            } else if fact.wrongPlayerIds.contains(player.id) {
                wrongStreak[player.id, default: 0] += 1
            }
        }

        var cues: [PresenterCue] = []
        let key: String
        if fact.correctPlayerIds.isEmpty { key = "result.everyoneWrong" }
        else if fact.wrongPlayerIds.isEmpty { key = "result.everyoneCorrect" }
        else { key = "result.mixed" }
        cues.append(universal(key: key, kind: .roundResult, expiry: .throughResults(roundId: fact.roundId)))

        if let leader = players.first(where: { wins[$0.id, default: 0] >= 4 }), titleByPlayer[leader.id] == nil {
            titleByPlayer[leader.id] = "IL KING"
            cues.append(namedCue(player: leader, title: "IL KING", factKey: "title.king", expiry: .whileFactIsTrue(key: "leader:\(leader.id)")))
        } else if intensity == .savage,
                  let target = players.first(where: { wrongStreak[$0.id, default: 0] >= 3 }),
                  titleByPlayer[target.id] == nil {
            titleByPlayer[target.id] = "QUELLO CHE NON LEGGE"
            cues.append(namedCue(player: target, title: "QUELLO CHE NON LEGGE", factKey: "title.doesNotRead", expiry: .whileFactIsTrue(key: "wrongStreak:\(target.id)")))
        }
        return cues
    }

    public func gameEnd(winner: PresenterPlayer?) -> PresenterCue {
        if let winner, let spoken = disambiguatedName(for: winner, among: [winner]) {
            return PresenterCue(id: nextId("gameEnd.named"), kind: .gameEnd, text: "\(spoken) HA VINTO. TECNICAMENTE.", targetPlayerId: winner.id, expiry: .whileGameEnd, cacheable: true)
        }
        return universal(key: "gameEnd", kind: .gameEnd, expiry: .whileGameEnd)
    }

    public func currentTitle(for playerId: String) -> String? { titleByPlayer[playerId] }

    public func returningCue(player: PresenterPlayer, title: String) -> PresenterCue {
        let name = player.spokenName?.uppercased()
        let text = name.map { "È TORNATO \($0), \(title)." } ?? "È TORNATO \(title)."
        return PresenterCue(id: nextId("lobby.returning"), kind: .lobby, text: text, targetPlayerId: player.id, expiry: .whileLobby, cacheable: name != nil)
    }

    public func crownWinner(_ playerId: String) {
        titleByPlayer[playerId] = "IL KING INDISCUSSO"
    }

    public func disambiguatedName(for player: PresenterPlayer, among players: [PresenterPlayer]) -> String? {
        guard let base = player.spokenName else { return nil }
        let matches = players.filter { $0.spokenName?.localizedCaseInsensitiveCompare(base) == .orderedSame }
        guard matches.count > 1 else { return base.uppercased() }
        guard let index = matches.firstIndex(where: { $0.id == player.id }) else { return base.uppercased() }
        if index == 0 { return "IL VERO \(base.uppercased())" }
        if index == 1 { return "L'ALTRO \(base.uppercased())" }
        return "L'ALTRO ALTRO \(base.uppercased())"
    }

    private func namedCue(player: PresenterPlayer, title: String, factKey: String, expiry: PresenterExpiry) -> PresenterCue {
        let name = player.spokenName?.uppercased()
        let text = name.map { "\($0), DA ORA SEI \(title)." } ?? "DA ORA SEI \(title)."
        return PresenterCue(id: nextId(factKey), kind: .title, text: text, targetPlayerId: player.id, expiry: expiry, cacheable: name != nil)
    }

    private func universal(key: String, kind: PresenterCueKind, expiry: PresenterExpiry) -> PresenterCue {
        let variants = OfflinePresenterPack.lines[key] ?? ["INTERESSANTE."]
        let recent = Set(recentLineIds.suffix(4))
        let offset = sequence % max(variants.count, 1)
        let indexed = variants.indices.map { variants.index(variants.startIndex, offsetBy: ($0 + offset) % variants.count) }
        let chosenIndex = indexed.first { !recent.contains("\(key).\($0)") } ?? variants.startIndex
        let lineId = "\(key).\(chosenIndex)"
        recentLineIds.append(lineId)
        sequence += 1
        return PresenterCue(id: "pack.v\(OfflinePresenterPack.version).\(lineId)", kind: kind, text: variants[chosenIndex], expiry: expiry, cacheable: true)
    }

    private func nextId(_ prefix: String) -> String {
        sequence += 1
        return "\(prefix).\(sequence)"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
