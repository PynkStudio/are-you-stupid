import AYSProtocol
import SwiftUI

struct ResultsView: View {
    @ObservedObject var model: HostViewModel
    let results: [PlayerRoundResult]

    private var correctCount: Int { results.filter(\.correct).count }
    private var verdict: String {
        if correctCount == results.count { return "SUSPICIOUSLY COMPETENT" }
        if correctCount == 0 { return "NOBODY READ THE INSTRUCTION" }
        if correctCount == 1 { return "ONE BRAINCELL SURVIVED" }
        return "MIXED LEVELS OF EMBARRASSMENT"
    }

    var body: some View {
        ZStack {
            GameStageBackground(accent: correctCount == 0 ? Theme.wrong : Theme.hotPink)
            HStack(alignment: .top, spacing: 34) {
                VStack(alignment: .leading, spacing: 18) {
                    LiveBug(text: "THE DAMAGE REPORT", color: Theme.hotPink)
                    ShoutText(text: verdict, size: 37, color: Theme.sunshine)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(Array(results.enumerated()), id: \.element.playerId) { index, result in
                                ResultCard(model: model, result: result, index: index)
                            }
                        }
                    }

                    if let commentary = model.lastAiCommentary, !commentary.isEmpty {
                        HStack(spacing: 10) {
                            Text("HOST SAYS").font(Theme.label(10)).foregroundStyle(Theme.cyan)
                            Text(commentary.uppercased()).font(Theme.label(14)).foregroundStyle(Color.white.opacity(0.72))
                        }
                    } else {
                        Text("NEXT BAD DECISION LOADING…")
                            .font(Theme.label(12)).foregroundStyle(Color.white.opacity(0.35))
                    }
                }
                ScoreboardView(model: model, title: "WHO'S LEAST STUPID?")
                    .frame(width: 330)
            }
            .padding(42)
        }
    }
}

private struct ResultCard: View {
    @ObservedObject var model: HostViewModel
    let result: PlayerRoundResult
    let index: Int

    var body: some View {
        HStack(spacing: 14) {
            Text(result.correct ? "✓" : "✕")
                .font(Theme.title(25)).foregroundStyle(result.correct ? Theme.correct : Theme.wrong)
                .frame(width: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.name(for: result.playerId)).font(Theme.label(19))
                if !result.correct && !result.reason.isEmpty {
                    Text(result.reason.uppercased())
                        .font(Theme.label(10)).foregroundStyle(Color.white.opacity(0.45)).lineLimit(1)
                } else {
                    Text(result.correct ? "SOMEHOW GOT IT RIGHT" : "YOU HAD ONE JOB")
                        .font(Theme.label(10)).foregroundStyle(Color.white.opacity(0.35))
                }
            }
            Spacer()
            if result.scoreDelta != 0 {
                Text("+\(result.scoreDelta)").font(Theme.title(18)).foregroundStyle(Theme.sunshine)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17)
            .stroke(result.correct ? Theme.correct.opacity(0.3) : Theme.wrong.opacity(0.3)))
    }
}
