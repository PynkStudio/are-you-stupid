//
//  RoundView.swift
//  AYSHost
//
//  "ROUND N -> GET READY... -> 3 2 1 GO -> live check marks" per
//  docs/Gameplay/Multiplayer Gameplay.md "TV presentation". The actual
//  challenge content isn't rendered here — that decision is still open
//  ([[Multiplayer Challenges]] "Phase 4 open question") — this screen only
//  shows the round's shared countdown/status, which is real and correct
//  regardless of that choice. A corner scoreboard carries over from the
//  previous round's standings (empty on round 1) — "live scoreboard during
//  appropriate moments" per the same doc.
//

import SwiftUI

struct RoundView: View {
    @ObservedObject var model: HostViewModel
    let roundId: String

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 32) {
                Spacer()
                switch model.countdownState {
                case "READY", nil:
                    ShoutText(text: "GET READY…", size: 64, color: Theme.accent)
                case "GO":
                    ShoutText(text: "GO!", size: 96, color: Theme.correct)
                default:
                    ShoutText(text: "ROUND IN PROGRESS", size: 48)
                }
                Text("ROUND ID \(roundId)")
                    .font(Theme.label(16))
                    .foregroundStyle(.gray)
                if let directorName = model.directorName {
                    Text("AI: \(directorName)")
                        .font(Theme.label(14))
                        .foregroundStyle(.gray)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)

            if !model.standings.isEmpty {
                ScoreboardView(model: model)
                    .padding(24)
            }
        }
    }
}
