import AYSHostCore
import SwiftUI

struct RoundView: View {
    @ObservedObject var model: HostViewModel
    let roundId: String

    private var presentation: (eyebrow: String, title: String, note: String, color: Color) {
        let t = model.strings
        switch model.countdownState {
        case "READY", nil:
            return (t(.phonesUp), t(.getReady), t(.readTwice), Theme.sunshine)
        case "GO":
            return (t(.noExcuses), t(.go), t(.doTheThing), Theme.correct)
        default:
            return (t(.liveRound), t(.dontPanic), t(.everyoneSees), Theme.cyan)
        }
    }

    private var headerDetail: String {
        if let total = model.totalRounds { return "\(model.strings(.ofTotal, ["n": total]))  ·  STUPID BATTLE" }
        return "LAST STUPID STANDING"
    }

    var body: some View {
        let copy = presentation
        ZStack {
            GameStageBackground(accent: copy.color)
            BoardCanvas { u in
                VStack(spacing: 0) {
                    BoardHeader(title: model.strings(.roundTitle, ["n": max(1, model.roundNumber)]), detail: headerDetail, unit: u)
                    Spacer()
                    VStack(spacing: 16 * u) {
                        Text(copy.eyebrow).font(Theme.label(18 * u)).tracking(5 * u).foregroundStyle(copy.color)
                        ShoutText(text: copy.title, size: (model.countdownState == "GO" ? 150 : 92) * u)
                            .shadow(color: copy.color.opacity(0.45), radius: 30 * u)
                        Text(copy.note).font(Theme.label(18 * u)).foregroundStyle(Color.white.opacity(0.55))
                    }
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 6 * u) {
                            if let directorName = model.directorName {
                                Text(model.strings(.chaosDirector, ["name": directorName]))
                                    .font(Theme.label(12 * u)).foregroundStyle(Color.white.opacity(0.45))
                            }
                            Text(model.strings(.tvJudging)).font(Theme.label(12 * u)).foregroundStyle(Color.white.opacity(0.32))
                        }
                        Spacer()
                        if !model.standings.isEmpty {
                            ScoreboardView(model: model, title: model.strings(.standings), compact: true, unit: u, maxRows: 5)
                                .frame(width: 300 * u)
                        }
                    }
                }
                .padding(.horizontal, 52 * u).padding(.vertical, 38 * u)
            }
        }
    }
}
