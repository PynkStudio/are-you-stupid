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

    var body: some View {
        let copy = presentation
        ZStack {
            GameStageBackground(accent: copy.color)
            VStack(spacing: 0) {
                HStack {
                    LiveBug(text: "PARTY IN PROGRESS", color: copy.color)
                    Spacer()
                    if let directorName = model.directorName {
                        Text("CHAOS DIRECTOR  ·  \(directorName)")
                            .font(Theme.label(11)).foregroundStyle(Color.white.opacity(0.45))
                    }
                }
                Spacer()
                VStack(spacing: 15) {
                    Text(copy.eyebrow).font(Theme.label(16)).tracking(4).foregroundStyle(copy.color)
                    ShoutText(text: copy.title, size: copy.title == "GO!" ? 116 : 72)
                        .shadow(color: copy.color.opacity(0.45), radius: 28)
                    Text(copy.note).font(Theme.label(15)).foregroundStyle(Color.white.opacity(0.52))
                }
                Spacer()
                HStack(alignment: .bottom) {
                    Text("THE TV IS JUDGING YOU.").font(Theme.label(11)).foregroundStyle(Color.white.opacity(0.32))
                    Spacer()
                    if !model.standings.isEmpty {
                        ScoreboardView(model: model, title: "CURRENT DAMAGE", compact: true).frame(width: 300)
                    }
                }
            }
            .padding(42)
        }
    }
}
