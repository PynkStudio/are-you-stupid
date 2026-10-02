import AYSProtocol
import SwiftUI

struct GameEndView: View {
    @ObservedObject var model: HostViewModel
    let gameEnd: GameEnd
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var winnerIsVisible = false

    private var standings: [GameResultEntry] {
        gameEnd.results.sorted { $0.standing < $1.standing }
    }

    var body: some View {
        ZStack {
            GameStageBackground(accent: Theme.sunshine)
            HStack(spacing: 44) {
                VStack(alignment: .leading, spacing: 17) {
                    LiveBug(text: "BREAKING NEWS", color: Theme.sunshine)
                    Text("AGAINST ALL ODDS,")
                        .font(Theme.label(15)).tracking(3).foregroundStyle(Theme.hotPink)
                    ShoutText(text: "NOT STUPID\nAFTER ALL", size: 50, color: Theme.sunshine)
                        .multilineTextAlignment(.leading)
                    if let winnerId = gameEnd.winnerId {
                        Text(model.name(for: winnerId))
                            .font(.system(size: 70, weight: .black, design: .rounded))
                            .minimumScaleFactor(0.6).lineLimit(1)
                            .scaleEffect(winnerIsVisible ? 1 : 0.72)
                            .opacity(winnerIsVisible ? 1 : 0)
                    }
                    Text((model.lastAiCommentary?.isEmpty == false
                          ? model.lastAiCommentary!
                          : "EVERYONE ELSE: MAYBE NEXT TIME.").uppercased())
                        .font(Theme.label(13)).foregroundStyle(Color.white.opacity(0.42))
                    Button(action: { model.rematch() }) {
                        HStack {
                            Text("RUN IT BACK")
                            Spacer()
                            Text("↻")
                        }
                        .font(Theme.title(20)).padding(.horizontal, 22).padding(.vertical, 16)
                        .frame(maxWidth: 370)
                    }
                    .background(Theme.sunshine).foregroundStyle(Theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    #if os(tvOS)
                    .buttonStyle(.card)
                    #else
                    .buttonStyle(.plain)
                    #endif
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                FinalStandings(model: model, gameEnd: gameEnd, standings: standings)
                    .frame(width: 410)
            }
            .padding(50)
        }
        .onAppear {
            if reduceMotion {
                winnerIsVisible = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.62).delay(0.12)) {
                    winnerIsVisible = true
                }
            }
        }
    }
}

private struct FinalStandings: View {
    @ObservedObject var model: HostViewModel
    let gameEnd: GameEnd
    let standings: [GameResultEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FINAL DAMAGE").font(Theme.label(14)).foregroundStyle(Theme.cyan)
            ForEach(standings, id: \.playerId) { entry in
                HStack(spacing: 13) {
                    Text(entry.standing == 1 ? "★" : "#\(entry.standing)")
                        .font(Theme.title(17))
                        .foregroundStyle(entry.standing == 1 ? Theme.sunshine : Color.white.opacity(0.35))
                        .frame(width: 38, alignment: .leading)
                    Text(model.name(for: entry.playerId)).font(Theme.label(19)).lineLimit(1)
                    Spacer()
                    if gameEnd.mode == .stupidBattle {
                        Text("\(entry.score)").font(Theme.title(19)).monospacedDigit()
                    } else if let lives = entry.lives {
                        Text(lives > 0 ? String(repeating: "♥", count: lives) : "OUT")
                            .font(Theme.label(13)).foregroundStyle(lives > 0 ? Theme.hotPink : Theme.wrong)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 13)
                .background(entry.standing == 1 ? Theme.sunshine.opacity(0.12) : .black.opacity(0.3),
                            in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(entry.standing == 1 ? Theme.sunshine.opacity(0.55) : Color.white.opacity(0.08)))
            }
        }
        .padding(22)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 24))
    }
}
