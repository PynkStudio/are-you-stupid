//
//  ChallengePicker.swift
//  AYSHostCore
//
//  Picks the next challengeId for a round. Unlike judging, picking has no
//  cross-language constraint — the host tells every phone what it picked via
//  ROUND_START, so it's free to use ordinary Swift randomness. Mirrors the
//  spirit of the Dart ChallengeGenerator (level-gated, weighted, no
//  immediate repeat, starters only through level 3 —
//  docs/Gameplay/Game Design Pillars.md) without needing to match its exact
//  sequence.
//

import Foundation

public protocol ChallengePicker {
    /// Picks a challengeId eligible at `level`, avoiding an immediate repeat
    /// of `lastId` when another eligible template exists.
    func pick(level: Int, lastId: String?) -> String
}

public final class WeightedChallengePicker: ChallengePicker {
    private let catalog: [ChallengeCatalogEntry]

    public init(catalog: [ChallengeCatalogEntry] = AYSChallengeCatalog.all) {
        precondition(!catalog.isEmpty, "ChallengeCatalogEntry catalog must not be empty")
        self.catalog = catalog
    }

    public func pick(level: Int, lastId: String?) -> String {
        var eligible = catalog.filter { $0.minLevel <= level }
        if eligible.isEmpty { eligible = catalog }

        // Levels 1-3 stay trivial: starter templates only, when any qualify.
        if level <= 3 {
            let starters = eligible.filter(\.starter)
            if !starters.isEmpty { eligible = starters }
        }

        // Avoid an immediate repeat when there's another option.
        if eligible.count > 1, let lastId {
            let withoutLast = eligible.filter { $0.id != lastId }
            if !withoutLast.isEmpty { eligible = withoutLast }
        }

        let totalWeight = eligible.reduce(0.0) { $0 + $1.weight }
        var roll = Double.random(in: 0..<totalWeight)
        for entry in eligible {
            roll -= entry.weight
            if roll <= 0 { return entry.id }
        }
        return eligible[eligible.count - 1].id
    }
}
