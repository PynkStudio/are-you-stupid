//
//  LobbyView.swift
//  AYSHost
//
//  Room code, join QR, live roster, START GAME gate (>=2 ready) — the
//  responsibilities list in docs/Architecture/Multiplayer Host (tvOS).md.
//

import AYSProtocol
import SwiftUI

struct LobbyView: View {
    @ObservedObject var model: HostViewModel

    var body: some View {
        HStack(spacing: 48) {
            VStack(spacing: 24) {
                ShoutText(text: "SCAN TO JOIN", size: 28, color: Theme.accent)
                model.joinQRImage
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 220, height: 220)
                    .background(Color.white)
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(12)
                VStack(spacing: 4) {
                    Text("ROOM CODE")
                        .font(Theme.label(18))
                        .foregroundStyle(.gray)
                    Text(model.roomCode)
                        .font(.system(size: 56, weight: .black, design: .monospaced))
                        .tracking(8)
                }
                Text(model.networkStatus)
                    .font(Theme.label(14))
                    .foregroundStyle(.gray)
                #if os(macOS)
                AirPlayButton()
                    .frame(width: 32, height: 32)
                #endif
            }
            .frame(maxWidth: 320)

            VStack(alignment: .leading, spacing: 16) {
                ShoutText(text: "PLAYERS", size: 28)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if model.roster.isEmpty {
                    Text("Waiting for players to join…")
                        .font(Theme.label(20))
                        .foregroundStyle(.gray)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(model.roster, id: \.playerId) { player in
                                PlayerRow(player: player)
                            }
                        }
                    }
                }

                Spacer()

                ModePicker(model: model)

                Button(action: { model.startGame() }) {
                    Text("START GAME (\(model.readyCount) READY)")
                        .font(Theme.label(24))
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .disabled(!model.canStart)
                .opacity(model.canStart ? 1 : 0.4)
                .background(Theme.accent)
                .foregroundStyle(.black)
                .cornerRadius(16)
                #if os(tvOS)
                .buttonStyle(.card)
                #else
                .buttonStyle(.plain)
                #endif
            }
        }
        .padding(48)
    }
}

/// Two-way mode toggle — docs/Gameplay/Multiplayer Gameplay.md "MODE 1 —
/// LAST STUPID STANDING" / "MODE 2 — STUPID BATTLE". A plain `Picker` would
/// pull in each platform's native control chrome, breaking the game-show
/// look every other element here shares — this stays in-house like the
/// rest of the UI (`ShoutText`, the cards).
private struct ModePicker: View {
    @ObservedObject var model: HostViewModel

    var body: some View {
        HStack(spacing: 12) {
            option("STUPID BATTLE", mode: .stupidBattle)
            option("LAST STUPID STANDING", mode: .lastStupidStanding)
        }
    }

    private func option(_ title: String, mode: GameMode) -> some View {
        let selected = model.selectedMode == mode
        return Button(action: { model.selectedMode = mode }) {
            Text(title)
                .font(Theme.label(14))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .background(selected ? Theme.accent : Theme.cardBackground)
        .foregroundStyle(selected ? .black : .white)
        .cornerRadius(12)
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
    }
}

private struct PlayerRow: View {
    let player: PlayerInfo

    var body: some View {
        HStack {
            Text(player.emoji.isEmpty ? "🙂" : player.emoji)
                .font(.system(size: 32))
            Text(player.playerName.uppercased())
                .font(Theme.label(22))
            Spacer()
            Text(player.ready ? "READY" : "…")
                .font(Theme.label(18))
                .foregroundStyle(player.ready ? Theme.correct : .gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }
}
