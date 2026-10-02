//
//  ResultsView.swift
//  AYSHost
//
//  "RESULTS board, then NEXT ROUND" — docs/Gameplay/Multiplayer Gameplay.md
//  "TV presentation". Only reached when the match isn't decided yet; a
//  decided round jumps straight to GAME_END (HostViewModel.handle processes
//  ROUND_RESULTS then GAME_END in the same broadcast burst).
//
//  Advances to the next round on its own after a short reveal pause
//  (HostViewModel.scheduleAutoAdvance) — no host button, per the "no
//  downtime" pillar.
//

import AYSProtocol
import SwiftUI

struct ResultsView: View {
    @ObservedObject var model: HostViewModel
    let results: [PlayerRoundResult]

    var body: some View {
        HStack(alignment: .top, spacing: 48) {
            VStack(spacing: 24) {
                ShoutText(text: "RESULTS", size: 48, color: Theme.accent)

                VStack(spacing: 10) {
                    ForEach(results, id: \.playerId) { result in
                        HStack {
                            Text(model.name(for: result.playerId))
                                .font(Theme.label(22))
                            Spacer()
                            Text(result.correct ? "✓" : "✕")
                                .font(Theme.label(28))
                                .foregroundStyle(result.correct ? Theme.correct : Theme.wrong)
                            if result.scoreDelta != 0 {
                                Text("+\(result.scoreDelta)")
                                    .font(Theme.label(18))
                                    .foregroundStyle(.gray)
                            }
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                    }
                }
                .frame(maxWidth: 480)

                Text("NEXT ROUND…")
                    .font(Theme.label(16))
                    .foregroundStyle(.gray)
            }

            ScoreboardView(model: model, title: "STANDINGS")
                .frame(minWidth: 220)
        }
        .padding(48)
    }
}
