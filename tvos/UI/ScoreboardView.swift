import AYSProtocol
import SwiftUI

struct ScoreboardView: View {
    @ObservedObject var model: HostViewModel
    var title: String? = nil
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            if let title {
                HStack {
                    Text(title.uppercased()).font(Theme.label(compact ? 11 : 15))
                    Spacer()
                    Text("LIVE").font(Theme.label(9)).foregroundStyle(Theme.hotPink)
                }
                .foregroundStyle(Theme.sunshine)
            }
            ForEach(Array(model.sortedStandings.enumerated()), id: \.element.playerId) { index, entry in
                ScoreRow(rank: index + 1, name: model.name(for: entry.playerId), entry: entry, compact: compact)
            }
        }
        .padding(compact ? 14 : 20)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: compact ? 16 : 22))
        .overlay(RoundedRectangle(cornerRadius: compact ? 16 : 22).stroke(Color.white.opacity(0.1)))
    }
}

private struct ScoreRow: View {
    let rank: Int
    let name: String
    let entry: PlayerScore
    let compact: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(rank == 1 ? "★" : "\(rank)")
                .font(Theme.label(compact ? 12 : 16))
                .foregroundStyle(rank == 1 ? Theme.sunshine : Color.white.opacity(0.35))
                .frame(width: 20, alignment: .leading)
            Text(name).font(Theme.label(compact ? 14 : 18)).lineLimit(1)
            Spacer(minLength: 8)
            if let lives = entry.lives {
                Text(lives > 0 ? String(repeating: "♥", count: lives) : "OUT")
                    .font(Theme.label(compact ? 11 : 14))
                    .foregroundStyle(lives > 0 ? Theme.hotPink : Theme.wrong)
            } else {
                Text("\(entry.score)").font(Theme.label(compact ? 14 : 19)).monospacedDigit()
            }
        }
    }
}
