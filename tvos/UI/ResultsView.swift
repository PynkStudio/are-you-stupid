import AYSProtocol
import SwiftUI

/// The round reveal. It holds for only `resultsPauseSeconds`, so the
/// hierarchy is strict: who failed and why (the joke) is the biggest thing on
/// screen, eliminations outrank everything, survivors collapse into one
/// compact strip with the fastest thumb called out, and the standings with
/// rank movement sit to the side.
struct ResultsView: View {
    @ObservedObject var model: HostViewModel
    let results: [PlayerRoundResult]

    private var failed: [PlayerRoundResult] { results.filter { !$0.correct } }
    private var survived: [PlayerRoundResult] {
        results.filter(\.correct).sorted { ($0.reactionMs ?? .max) < ($1.reactionMs ?? .max) }
    }
    private var isElimination: Bool { model.matchMode == .lastStupidStanding }
    private var eliminated: [PlayerRoundResult] {
        guard isElimination else { return [] }
        return failed.filter { model.livesBeforeRound(for: $0.playerId) <= 1 }
    }

    private var tally: (text: String, color: Color) {
        if failed.isEmpty { return ("EVERYONE GOT IT RIGHT", Theme.correct) }
        if survived.isEmpty { return ("EVERYONE FAILED", Theme.wrong) }
        return ("\(failed.count) OF \(results.count) FAILED", Theme.hotPink)
    }

    private var verdict: String {
        if eliminated.count == 1 { return "\(model.name(for: eliminated[0].playerId)) IS OUT." }
        if eliminated.count > 1 { return "\(eliminated.count) PLAYERS ARE OUT." }
        if failed.isEmpty { return "SUSPICIOUSLY COMPETENT" }
        if survived.isEmpty { return "NOBODY READ THE INSTRUCTION" }
        if failed.count == 1 { return "\(model.name(for: failed[0].playerId)) HAD ONE JOB." }
        if survived.count == 1 { return "ONE BRAINCELL SURVIVED" }
        return failed.count > survived.count ? "MOSTLY STUPID" : "MIXED LEVELS OF EMBARRASSMENT"
    }

    private var headerDetail: String {
        if let total = model.totalRounds { return "OF \(total)  ·  STUPID BATTLE" }
        let alive = results.count - eliminated.count
        return "LAST STUPID STANDING  ·  \(alive) STILL IN"
    }

    var body: some View {
        ZStack {
            GameStageBackground(accent: survived.isEmpty || !eliminated.isEmpty ? Theme.wrong : Theme.hotPink)
            BoardCanvas { u in
                VStack(alignment: .leading, spacing: 0) {
                    BoardHeader(title: "ROUND \(max(1, model.roundNumber))", detail: headerDetail, unit: u)
                    HStack(alignment: .top, spacing: 40 * u) {
                        VStack(alignment: .leading, spacing: 18 * u) {
                            VStack(alignment: .leading, spacing: 6 * u) {
                                Text(tally.text).font(Theme.label(15 * u)).tracking(3 * u).foregroundStyle(tally.color)
                                Text(verdict)
                                    .font(Theme.title(52 * u)).foregroundStyle(Theme.sunshine)
                                    .lineLimit(2).minimumScaleFactor(0.6)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if failed.isEmpty {
                                FastestHero(model: model, result: survived.first, unit: u)
                            } else {
                                FailWall(model: model, failed: failed, isElimination: isElimination, unit: u)
                                if !survived.isEmpty {
                                    SurvivorStrip(model: model, survived: survived, unit: u)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        ScoreboardView(model: model, title: "STANDINGS", unit: u)
                            .frame(width: 340 * u)
                    }
                    .padding(.top, 26 * u)
                    .frame(maxHeight: .infinity, alignment: .top)

                    VStack(alignment: .leading, spacing: 18 * u) {
                        if let line = model.lastAiCommentary, !line.isEmpty {
                            PresenterCaption(text: line, unit: u)
                        }
                        AdvanceBar(label: "NEXT ROUND", duration: model.resultsPauseSeconds, unit: u)
                    }
                    .padding(.top, 18 * u)
                }
                .padding(.horizontal, 52 * u).padding(.vertical, 38 * u)
            }
        }
    }
}

/// The wrong answers, biggest first: each card carries the player's real
/// one-line failure reason at a size you can read from the sofa. Density
/// steps down as the wall fills (1 → 2 → 3 columns) instead of scrolling.
private struct FailWall: View {
    @ObservedObject var model: HostViewModel
    let failed: [PlayerRoundResult]
    let isElimination: Bool
    let unit: CGFloat

    var body: some View {
        let columns = failed.count <= 3 ? 1 : failed.count <= 8 ? 2 : 3
        let scale: CGFloat = columns == 1 ? 1 : columns == 2 ? 0.8 : 0.68
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12 * unit), count: columns),
                  alignment: .leading, spacing: 12 * unit) {
            ForEach(Array(failed.enumerated()), id: \.element.playerId) { index, result in
                FailCard(model: model, result: result, isElimination: isElimination,
                         index: index, unit: unit * scale)
            }
        }
    }
}

private struct FailCard: View {
    @ObservedObject var model: HostViewModel
    let result: PlayerRoundResult
    let isElimination: Bool
    let index: Int
    let unit: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.boardStill) private var still
    @State private var revealed = false

    private var livesBefore: Int { model.livesBeforeRound(for: result.playerId) }
    private var isOut: Bool { isElimination && livesBefore <= 1 }
    private var reason: String { result.reason.isEmpty ? "YOU HAD ONE JOB." : result.reason.uppercased() }

    var body: some View {
        HStack(spacing: 16 * unit) {
            Text(model.emoji(for: result.playerId)).font(.system(size: 40 * unit))
            VStack(alignment: .leading, spacing: 4 * unit) {
                Text(model.name(for: result.playerId))
                    .font(Theme.title(32 * unit)).lineLimit(1).minimumScaleFactor(0.6)
                Text(reason)
                    .font(Theme.label(17 * unit)).foregroundStyle(Color.white.opacity(0.78))
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8 * unit)
            if isOut {
                Text("ELIMINATED")
                    .font(Theme.title(17 * unit)).tracking(1.5 * unit).foregroundStyle(Theme.wrong)
                    .padding(.horizontal, 10 * unit).padding(.vertical, 6 * unit)
                    .overlay(Rectangle().stroke(Theme.wrong, lineWidth: 3 * unit))
                    .rotationEffect(.degrees(-7))
                    .scaleEffect(revealed || reduceMotion || still ? 1 : 1.8)
            } else if isElimination {
                HeartsView(remaining: max(0, livesBefore - 1), total: model.startingLives,
                           lostThisRound: true, size: 20 * unit)
            }
        }
        .padding(.leading, 20 * unit).padding(.trailing, 22 * unit).padding(.vertical, 16 * unit)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.wrong.opacity(isOut ? 0.22 : 0.13), in: RoundedRectangle(cornerRadius: 14 * unit))
        .overlay(alignment: .leading) { Rectangle().fill(Theme.wrong).frame(width: 6 * unit) }
        .clipShape(RoundedRectangle(cornerRadius: 14 * unit))
        .opacity(revealed || reduceMotion || still ? 1 : 0)
        .offset(x: revealed || reduceMotion || still ? 0 : -24 * unit)
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72).delay(0.05 + Double(index) * 0.06)) {
                revealed = true
            }
        }
    }
}

/// Everyone who got it right, in one line-up ordered by speed. The fastest
/// gets the only highlight; the rest are deliberately quiet.
private struct SurvivorStrip: View {
    @ObservedObject var model: HostViewModel
    let survived: [PlayerRoundResult]
    let unit: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10 * unit) {
            Text("GOT IT RIGHT").font(Theme.label(12 * unit)).tracking(2.5 * unit).foregroundStyle(Theme.correct)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190 * unit), spacing: 10 * unit, alignment: .leading)],
                      alignment: .leading, spacing: 8 * unit) {
                ForEach(Array(survived.enumerated()), id: \.element.playerId) { index, result in
                    let fastest = index == 0 && survived.count > 1 && result.reactionMs != nil
                    HStack(spacing: 8 * unit) {
                        Text(model.emoji(for: result.playerId)).font(.system(size: 17 * unit))
                        Text(model.name(for: result.playerId))
                            .font(Theme.title(17 * unit)).lineLimit(1).minimumScaleFactor(0.7)
                            .foregroundStyle(fastest ? Theme.sunshine : .white)
                        if let ms = result.reactionMs {
                            Text(fastest ? "⚡ \(ms.asSeconds)" : ms.asSeconds)
                                .font(Theme.label(12 * unit)).monospacedDigit()
                                .foregroundStyle(fastest ? Theme.sunshine : Color.white.opacity(0.42))
                        }
                    }
                }
            }
        }
        .padding(.top, 4 * unit)
    }
}

/// A clean round has no failure to show, so the speed race becomes the story.
private struct FastestHero: View {
    @ObservedObject var model: HostViewModel
    let result: PlayerRoundResult?
    let unit: CGFloat

    var body: some View {
        if let result {
            VStack(alignment: .leading, spacing: 6 * unit) {
                Text("FASTEST THUMB").font(Theme.label(13 * unit)).tracking(2.5 * unit).foregroundStyle(Theme.cyan)
                HStack(alignment: .firstTextBaseline, spacing: 16 * unit) {
                    Text(model.emoji(for: result.playerId)).font(.system(size: 54 * unit))
                    Text(model.name(for: result.playerId))
                        .font(Theme.title(64 * unit)).lineLimit(1).minimumScaleFactor(0.5)
                    if let ms = result.reactionMs {
                        Text(ms.asSeconds).font(Theme.title(30 * unit)).monospacedDigit()
                            .foregroundStyle(Theme.sunshine)
                    }
                }
                Text("NOBODY FAILED. WE'RE AS SURPRISED AS YOU.")
                    .font(Theme.label(15 * unit)).foregroundStyle(Color.white.opacity(0.5))
            }
            .padding(.top, 14 * unit)
        }
    }
}
