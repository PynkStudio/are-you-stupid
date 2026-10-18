import AYSHostCore
import AYSProtocol
import SwiftUI

/// The final board. One hero (the winner, or the room's collective failure
/// when Last Stupid Standing ends with nobody alive), then awards earned from
/// real match stats, then the full ranking with the last place called out.
struct GameEndView: View {
    @ObservedObject var model: HostViewModel
    let gameEnd: GameEnd

    private var standings: [GameResultEntry] {
        gameEnd.results.sorted { $0.standing < $1.standing }
    }

    private var headerDetail: String {
        let rounds = model.roundNumber == 1
            ? model.strings(.roundsOne) : model.strings(.roundsDetail, ["n": model.roundNumber])
        return gameEnd.mode == .stupidBattle ? "STUPID BATTLE  ·  \(rounds)" : "LAST STUPID STANDING  ·  \(rounds)"
    }

    var body: some View {
        ZStack {
            GameStageBackground(accent: gameEnd.winnerId == nil && gameEnd.tiedLeaderIds.isEmpty ? Theme.wrong : Theme.sunshine)
            BoardCanvas { u in
                VStack(alignment: .leading, spacing: 0) {
                    BoardHeader(title: model.strings(.final), detail: headerDetail, unit: u)
                    HStack(alignment: .center, spacing: 44 * u) {
                        VStack(alignment: .leading, spacing: 34 * u) {
                            if let winnerId = gameEnd.winnerId,
                               let entry = standings.first(where: { $0.playerId == winnerId }) {
                                WinnerHero(model: model, entry: entry, mode: gameEnd.mode, unit: u)
                            } else if !gameEnd.tiedLeaderIds.isEmpty {
                                TieHero(model: model, gameEnd: gameEnd, unit: u)
                            } else {
                                NobodyWonHero(strings: model.strings, unit: u)
                            }
                            AwardsRow(model: model, unit: u)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        FinalStandings(model: model, gameEnd: gameEnd, standings: standings, unit: u)
                            .frame(width: 390 * u)
                    }
                    .frame(maxHeight: .infinity)

                    VStack(alignment: .leading, spacing: 16 * u) {
                        if let line = model.lastAiCommentary, !line.isEmpty {
                            PresenterCaption(text: line, unit: u)
                        }
                        RematchFooter(model: model, unit: u)
                    }
                }
                .padding(.horizontal, 52 * u).padding(.vertical, 38 * u)
            }
        }
    }
}

private struct WinnerHero: View {
    @ObservedObject var model: HostViewModel
    let entry: GameResultEntry
    let mode: GameMode
    let unit: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.boardStill) private var still
    @State private var revealed = false

    private var statLine: String {
        let t = model.strings
        var parts: [String] = []
        if mode == .stupidBattle { parts.append(t(.pts, ["n": entry.score])) }
        if let stats = model.matchStats[entry.playerId] {
            parts.append(t(.rightOfTotal, ["n": stats.correct, "total": stats.correct + stats.wrong]))
            if let avg = stats.averageReactionMs { parts.append(t(.avg, ["time": avg.asSeconds])) }
        }
        if mode == .lastStupidStanding, let lives = entry.lives {
            parts.append(lives == 1 ? t(.lifeLeftOne) : t(.livesLeft, ["n": lives]))
        }
        return parts.joined(separator: "  ·  ")
    }

    var body: some View {
        let shown = revealed || reduceMotion || still
        VStack(alignment: .leading, spacing: 10 * unit) {
            Text(model.strings(.leastStupid))
                .font(Theme.label(16 * unit)).tracking(3 * unit).foregroundStyle(Theme.cyan)
            HStack(alignment: .center, spacing: 22 * unit) {
                Text(model.emoji(for: entry.playerId)).font(.system(size: 92 * unit))
                Text(model.name(for: entry.playerId))
                    .font(.system(size: 120 * unit, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.sunshine)
                    .lineLimit(1).minimumScaleFactor(0.35)
                    .shadow(color: Theme.sunshine.opacity(0.45), radius: 30 * unit)
            }
            .scaleEffect(shown ? 1 : 0.7, anchor: .leading)
            .opacity(shown ? 1 : 0)
            if !statLine.isEmpty {
                Text(statLine).font(Theme.label(19 * unit)).monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.72))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62).delay(0.12)) { revealed = true }
        }
    }
}

/// Last Stupid Standing can end with the final survivors all losing their
/// last life on the same round. That is a punchline, not a winner.
private struct NobodyWonHero: View {
    let strings: BoardStrings
    let unit: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10 * unit) {
            Text(strings(.nobodySurvived)).font(Theme.label(16 * unit)).tracking(3 * unit).foregroundStyle(Theme.hotPink)
            Text(strings(.everyoneIsStupid))
                .font(.system(size: 104 * unit, weight: .black, design: .rounded))
                .foregroundStyle(Theme.sunshine).lineLimit(2).minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)
            Text(strings(.lastRoundTookOut))
                .font(Theme.label(19 * unit)).foregroundStyle(Color.white.opacity(0.72))
        }
    }
}

/// A Stupid Battle that ends on a shared top score: nobody is crowned by
/// join order. Every leader is named, and the score they share.
private struct TieHero: View {
    @ObservedObject var model: HostViewModel
    let gameEnd: GameEnd
    let unit: CGFloat

    var body: some View {
        let leaders = gameEnd.tiedLeaderIds
        let score = gameEnd.results.first { $0.standing == 1 }?.score ?? 0
        VStack(alignment: .leading, spacing: 10 * unit) {
            Text(model.strings(.itsATie)).font(Theme.label(16 * unit)).tracking(3 * unit).foregroundStyle(Theme.cyan)
            Text(model.strings(.equallyStupid))
                .font(.system(size: 104 * unit, weight: .black, design: .rounded))
                .foregroundStyle(Theme.sunshine).lineLimit(2).minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)
            Text(leaders.map { "\(model.emoji(for: $0)) \(model.name(for: $0))" }.joined(separator: "   "))
                .font(Theme.title(30 * unit)).lineLimit(2).minimumScaleFactor(0.5)
            Text(model.strings(.tiedOn, ["n": score]))
                .font(Theme.label(19 * unit)).foregroundStyle(Color.white.opacity(0.72))
        }
    }
}

/// Up to three awards, each backed by a real stat from this match. An award
/// with no qualifying data (nobody failed, no reaction times) is skipped.
private struct AwardsRow: View {
    @ObservedObject var model: HostViewModel
    let unit: CGFloat

    private struct Award: Identifiable {
        let id: String
        let title: String
        let playerId: String
        let value: String
        let color: Color
    }

    private var awards: [Award] {
        let stats = model.matchStats
        let t = model.strings
        var list: [Award] = []
        // Ties resolve by name so the same match always awards the same seat.
        let byName = stats.sorted { model.name(for: $0.key) < model.name(for: $1.key) }
        if let fast = byName.filter({ $0.value.bestReactionMs != nil })
            .min(by: { $0.value.bestReactionMs! < $1.value.bestReactionMs! }) {
            list.append(Award(id: "fast", title: t(.fastestThumb), playerId: fast.key,
                              value: fast.value.bestReactionMs!.asSeconds, color: Theme.cyan))
        }
        if let worst = byName.max(by: { $0.value.wrong < $1.value.wrong }), worst.value.wrong > 0 {
            list.append(Award(id: "fails", title: t(.professionallyStupid), playerId: worst.key,
                              value: worst.value.wrong == 1 ? t(.failOne) : t(.failsMany, ["n": worst.value.wrong]),
                              color: Theme.hotPink))
        }
        // Not a superlative, so it can skip players who already hold an
        // award and spread the spotlight across the room.
        let awarded = Set(list.map(\.playerId))
        if let roll = byName.filter({ !awarded.contains($0.key) })
            .max(by: { $0.value.longestStreak < $1.value.longestStreak }),
           roll.value.longestStreak >= 3 {
            list.insert(Award(id: "streak", title: t(.onARoll), playerId: roll.key,
                              value: t(.inARow, ["n": roll.value.longestStreak]), color: Theme.correct),
                        at: min(1, list.count))
        }
        return list
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14 * unit) {
            ForEach(awards) { award in
                VStack(alignment: .leading, spacing: 6 * unit) {
                    Rectangle().fill(award.color).frame(width: 28 * unit, height: 3 * unit)
                    Text(award.title).font(Theme.label(11 * unit)).tracking(2 * unit)
                        .foregroundStyle(award.color).lineLimit(1).minimumScaleFactor(0.7)
                    HStack(spacing: 8 * unit) {
                        Text(model.emoji(for: award.playerId)).font(.system(size: 20 * unit))
                        Text(model.name(for: award.playerId))
                            .font(Theme.title(22 * unit)).lineLimit(1).minimumScaleFactor(0.6)
                    }
                    Text(award.value).font(Theme.label(14 * unit)).monospacedDigit()
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .padding(16 * unit)
                .frame(maxWidth: 240 * unit, alignment: .leading)
                .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 14 * unit))
            }
        }
    }
}

private struct FinalStandings: View {
    @ObservedObject var model: HostViewModel
    let gameEnd: GameEnd
    let standings: [GameResultEntry]
    let unit: CGFloat

    /// The last seat, unless it is tied with the one above (a Last Stupid
    /// Standing wipe-out ranks everyone 0 lives): a tie earns no label.
    private var clearLastPlace: String? {
        guard standings.count > 2, let last = standings.last else { return nil }
        let above = standings[standings.count - 2]
        return (above.score, above.lives ?? 0) == (last.score, last.lives ?? 0) ? nil : last.playerId
    }

    var body: some View {
        let dense = standings.count > 8
        VStack(alignment: .leading, spacing: (dense ? 5 : 9) * unit) {
            Text(model.strings(.finalStandings)).font(Theme.label(13 * unit)).tracking(2 * unit)
                .foregroundStyle(Color.white.opacity(0.5)).padding(.bottom, 6 * unit)
            ForEach(standings, id: \.playerId) { entry in
                let isWinner = entry.playerId == gameEnd.winnerId || gameEnd.tiedLeaderIds.contains(entry.playerId)
                let isLast = entry.playerId == clearLastPlace
                let size: CGFloat = (dense ? 15 : 19) * unit
                HStack(spacing: 12 * unit) {
                    Text("\(entry.standing)").font(Theme.title(size * 0.85)).monospacedDigit()
                        .foregroundStyle(isWinner ? Theme.sunshine : Color.white.opacity(0.35))
                        .frame(width: 24 * unit, alignment: .leading)
                    Text(model.emoji(for: entry.playerId)).font(.system(size: size))
                    VStack(alignment: .leading, spacing: 1 * unit) {
                        Text(model.name(for: entry.playerId)).font(Theme.title(size)).lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(isWinner ? Theme.sunshine : .white)
                        if isLast {
                            Text(model.strings(.mostStupid)).font(Theme.label(10 * unit)).tracking(1 * unit)
                                .foregroundStyle(Theme.hotPink)
                        }
                    }
                    Spacer(minLength: 6 * unit)
                    if gameEnd.mode == .stupidBattle {
                        Text("\(entry.score)").font(Theme.title(size)).monospacedDigit()
                            .foregroundStyle(isWinner ? Theme.sunshine : .white)
                    } else if let lives = entry.lives {
                        if lives > 0 {
                            HeartsView(remaining: lives, total: model.startingLives, size: 13 * unit)
                        } else {
                            Text(model.strings(.out)).font(Theme.title(12 * unit)).foregroundStyle(Theme.wrong.opacity(0.8))
                        }
                    }
                }
                .padding(.vertical, (dense ? 2 : 5) * unit)
                .padding(.horizontal, isWinner ? 12 * unit : 0)
                .background(isWinner ? Theme.sunshine.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10 * unit))
                .padding(.horizontal, isWinner ? -12 * unit : 0)
            }
        }
        .padding(24 * unit)
        .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 18 * unit))
    }
}

private struct RematchFooter: View {
    @ObservedObject var model: HostViewModel
    let unit: CGFloat

    var body: some View {
        if let adPlayer = model.adBreakPlayerName {
            HStack(alignment: .firstTextBaseline, spacing: 16 * unit) {
                Text(model.strings(.sponsors)).font(Theme.title(20 * unit))
                Text(model.strings(.adPressed, ["name": adPlayer])).font(Theme.label(14 * unit))
                Spacer()
            }
            .padding(.horizontal, 22 * unit).padding(.vertical, 14 * unit)
            .background(Theme.hotPink, in: RoundedRectangle(cornerRadius: 12 * unit))
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 16 * unit) {
                Text(model.strings(.runItBack)).font(Theme.title(20 * unit))
                Text(model.strings(.anyPlayerRematch))
                    .font(Theme.label(14 * unit)).foregroundStyle(Color.white.opacity(0.5))
            }
        }
    }
}
