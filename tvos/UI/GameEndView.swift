//
//  GameEndView.swift
//  AYSHost
//
//  "Winner animation... then instant rematch back into the lobby" —
//  docs/Gameplay/Multiplayer Gameplay.md "Winner + rematch". No share-card
//  rendering yet (Phase 9, [[Multiplayer Development]]) — standings +
//  winner + REMATCH is the honest scope of this pass.
//

import AYSProtocol
import SwiftUI

struct GameEndView: View {
    @ObservedObject var model: HostViewModel
    let gameEnd: GameEnd

    private var standings: [GameResultEntry] {
        gameEnd.results.sorted { $0.standing < $1.standing }
    }

    var body: some View {
        VStack(spacing: 24) {
            ShoutText(text: "THE LEAST STUPID", size: 40, color: Theme.accent)
            if let winnerId = gameEnd.winnerId {
                Text(model.name(for: winnerId))
                    .font(.system(size: 64, weight: .black, design: .rounded))
            }

            VStack(spacing: 8) {
                ForEach(standings, id: \.playerId) { entry in
                    HStack {
                        Text("#\(entry.standing)")
                            .font(Theme.label(18))
                            .foregroundStyle(.gray)
                            .frame(width: 48, alignment: .leading)
                        Text(model.name(for: entry.playerId))
                            .font(Theme.label(22))
                        Spacer()
                        if gameEnd.mode == .stupidBattle {
                            Text("\(entry.score)")
                                .font(Theme.label(22))
                        } else if let lives = entry.lives {
                            Text(String(repeating: "❤️", count: max(0, lives)))
                        }
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(12)
                }
            }
            .frame(maxWidth: 480)

            Button(action: { model.rematch() }) {
                Text("REMATCH")
                    .font(Theme.label(24))
                    .padding()
                    .frame(maxWidth: 360)
            }
            .background(Theme.accent)
            .foregroundStyle(.black)
            .cornerRadius(16)
            #if os(tvOS)
            .buttonStyle(.card)
            #else
            .buttonStyle(.plain)
            #endif
        }
        .padding(48)
    }
}
