//
//  RootView.swift
//  AYSHost
//
//  Switches between the board screens off `HostViewModel.screen` — the same
//  shared round flow docs/Gameplay/Multiplayer Gameplay.md describes:
//  LOBBY -> ROUND -> RESULTS -> (next round, or) GAME_END -> rematch.
//

import SwiftUI

public struct AYSHostBoardView: View {
    @StateObject private var model = HostViewModel()

    public init() {}

    public var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch model.screen {
            case .lobby:
                LobbyView(model: model)
            case .round(let roundId):
                RoundView(model: model, roundId: roundId)
            case .results(let results, _):
                ResultsView(model: model, results: results)
            case .gameEnd(let gameEnd):
                GameEndView(model: model, gameEnd: gameEnd)
            }
        }
        .task { await model.startHosting() }
        .foregroundStyle(.white)
    }
}

#Preview {
    AYSHostBoardView()
}
