import AYSProtocol
import SwiftUI

/// Live standings. Rank movement since the round opened (▲/▼) is the second
/// story of every reveal after "who failed", so it sits next to the name;
/// eliminated players sink and fade instead of disappearing.
struct ScoreboardView: View {
    @ObservedObject var model: HostViewModel
    var title: String? = nil
    var compact = false
    var unit: CGFloat = 1
    /// Rows beyond this collapse into a "+N MORE" line (compact boards).
    var maxRows: Int = 16

    var body: some View {
        let rows = model.sortedStandings
        VStack(alignment: .leading, spacing: (compact ? 7 : 9) * unit) {
            if let title {
                Text(title.uppercased())
                    .font(Theme.label((compact ? 11 : 13) * unit)).tracking(2 * unit)
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.bottom, 4 * unit)
            }
            ForEach(Array(rows.prefix(maxRows).enumerated()), id: \.element.playerId) { index, entry in
                ScoreRow(model: model, rank: index + 1, entry: entry, compact: compact || rows.count > 9, unit: unit)
            }
            if rows.count > maxRows {
                Text("+\(rows.count - maxRows) MORE")
                    .font(Theme.label(11 * unit)).foregroundStyle(Color.white.opacity(0.4))
            }
        }
        .padding((compact ? 16 : 22) * unit)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 18 * unit))
    }
}

private struct ScoreRow: View {
    @ObservedObject var model: HostViewModel
    let rank: Int
    let entry: PlayerScore
    let compact: Bool
    let unit: CGFloat

    private var isOut: Bool { (entry.lives ?? 1) <= 0 }
    private var leads: Bool { rank == 1 && !isOut }

    var body: some View {
        let nameSize: CGFloat = (compact ? 15 : 19) * unit
        HStack(spacing: 10 * unit) {
            Text("\(rank)")
                .font(Theme.title((compact ? 13 : 16) * unit)).monospacedDigit()
                .foregroundStyle(leads ? Theme.sunshine : Color.white.opacity(0.35))
                .frame(width: 22 * unit, alignment: .leading)
            Text(model.emoji(for: entry.playerId)).font(.system(size: nameSize * 0.95))
            Text(model.name(for: entry.playerId))
                .font(Theme.title(nameSize)).lineLimit(1).minimumScaleFactor(0.7)
                .strikethrough(isOut, color: Color.white.opacity(0.5))
                .foregroundStyle(leads ? Theme.sunshine : .white)
            if let shift = model.rankShift(for: entry.playerId), shift != 0, !isOut {
                Text(shift > 0 ? "▲\(shift)" : "▼\(-shift)")
                    .font(Theme.label(11 * unit)).monospacedDigit()
                    .foregroundStyle(shift > 0 ? Theme.correct : Theme.hotPink)
            }
            Spacer(minLength: 6 * unit)
            if let lives = entry.lives {
                if isOut {
                    Text("OUT").font(Theme.title(12 * unit)).foregroundStyle(Theme.wrong)
                } else {
                    HeartsView(remaining: lives, total: model.startingLives, size: (compact ? 11 : 13) * unit)
                }
            } else {
                Text("\(entry.score)").font(Theme.title(nameSize)).monospacedDigit()
                    .foregroundStyle(leads ? Theme.sunshine : .white)
            }
        }
        .opacity(isOut ? 0.4 : 1)
    }
}
