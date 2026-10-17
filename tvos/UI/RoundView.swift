import SwiftUI

struct RoundView: View {
    @ObservedObject var model: HostViewModel
    let roundId: String

    private var presentation: (eyebrow: String, title: String, note: String, color: Color) {
        switch model.countdownState {
        case "READY", nil:
            return ("PHONES UP", "GET READY", "READ IT TWICE. YOU'LL STILL GET IT WRONG.", Theme.sunshine)
        case "GO":
            return ("NO EXCUSES", "GO!", "DO THE STUPIDLY SIMPLE THING.", Theme.correct)
        default:
            return ("LIVE ROUND", "DON'T PANIC", "EVERYONE CAN SEE YOU THINKING.", Theme.cyan)
        }
    }

    private var headerDetail: String {
        if let total = model.totalRounds { return "OF \(total)  ·  STUPID BATTLE" }
        return "LAST STUPID STANDING"
    }

    var body: some View {
        let copy = presentation
        ZStack {
            GameStageBackground(accent: copy.color)
            BoardCanvas { u in
                VStack(spacing: 0) {
                    BoardHeader(title: "ROUND \(max(1, model.roundNumber))", detail: headerDetail, unit: u)
                    Spacer()
                    VStack(spacing: 16 * u) {
                        Text(copy.eyebrow).font(Theme.label(18 * u)).tracking(5 * u).foregroundStyle(copy.color)
                        ShoutText(text: copy.title, size: (copy.title == "GO!" ? 150 : 92) * u)
                            .shadow(color: copy.color.opacity(0.45), radius: 30 * u)
                        Text(copy.note).font(Theme.label(18 * u)).foregroundStyle(Color.white.opacity(0.55))
                    }
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 6 * u) {
                            if let directorName = model.directorName {
                                Text("CHAOS DIRECTOR: \(directorName)")
                                    .font(Theme.label(12 * u)).foregroundStyle(Color.white.opacity(0.45))
                            }
                            Text("THE TV IS JUDGING YOU.").font(Theme.label(12 * u)).foregroundStyle(Color.white.opacity(0.32))
                        }
                        Spacer()
                        if !model.standings.isEmpty {
                            ScoreboardView(model: model, title: "STANDINGS", compact: true, unit: u, maxRows: 5)
                                .frame(width: 300 * u)
                        }
                    }
                }
                .padding(.horizontal, 52 * u).padding(.vertical, 38 * u)
            }
        }
    }
}
