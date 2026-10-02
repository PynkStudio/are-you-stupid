//
//  ScoreboardView.swift
//  AYSHost
//
//  "Live scoreboard during appropriate moments" — docs/Gameplay/Multiplayer
//  Gameplay.md "TV presentation":
//
//    STUPID BATTLE
//    SAMI     820
//    MASSIMO  760
//
//  Fed by HostViewModel.sortedStandings, itself built from every PLAYER_SCORE
//  broadcast — never waits for GAME_END.
//

import AYSProtocol
import SwiftUI

struct ScoreboardView: View {
    @ObservedObject var model: HostViewModel
    var title: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title.uppercased())
                    .font(Theme.label(16))
                    .foregroundStyle(Theme.accent)
            }
            ForEach(Array(model.sortedStandings.enumerated()), id: \.element.playerId) { index, entry in
                ScoreRow(rank: index + 1, name: model.name(for: entry.playerId), entry: entry)
            }
        }
    }
}

private struct ScoreRow: View {
    let rank: Int
    let name: String
    let entry: PlayerScore

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(Theme.label(16))
                .foregroundStyle(.gray)
                .frame(width: 20, alignment: .leading)
            Text(name)
                .font(Theme.label(18))
                .lineLimit(1)
            Spacer(minLength: 8)
            if let lives = entry.lives {
                Text(lives > 0 ? String(repeating: "❤️", count: lives) : "💀")
                    .font(.system(size: 14))
            } else {
                Text("\(entry.score)")
                    .font(Theme.label(18))
                    .monospacedDigit()
            }
        }
    }
}
