import Messages
import UIKit

final class MessagesViewController: MSMessagesAppViewController {
    private enum PlayMode { case firstNew, firstNext, second }

    private let background = UIColor(red: 0.035, green: 0.035, blue: 0.045, alpha: 1)
    private let ink = UIColor(red: 0.98, green: 0.96, blue: 0.90, alpha: 1)
    private let yellow = UIColor(red: 1, green: 0.82, blue: 0.02, alpha: 1)
    private let pink = UIColor(red: 1, green: 0.16, blue: 0.50, alpha: 1)
    private let green = UIColor(red: 0.18, green: 0.78, blue: 0.39, alpha: 1)
    private let red = UIColor(red: 0.93, green: 0.20, blue: 0.22, alpha: 1)
    private let blue = UIColor(red: 0.16, green: 0.56, blue: 0.96, alpha: 1)
    private let orange = UIColor(red: 1, green: 0.55, blue: 0.10, alpha: 1)

    /// Device language, so the extension speaks the same six languages as
    /// the game. Each device localizes on its own; the seeded sequence is
    /// identical regardless.
    private let language = MessageLanguage.preferred()

    private var stack = UIStackView()
    private var match: MessageMatch?
    private var playMode: PlayMode?
    /// Whether this device is the match's first player (opens every round).
    private var viewerIsFirst = true
    private var generator: StupidChallengeGenerator?
    private var currentChallenge: StupidChallenge?
    /// True between finishing a streak and sending it, so a presentation
    /// change cannot wipe the result screen.
    private var awaitingSend = false
    private var streak = 0
    private var elapsedMilliseconds = 0
    private var challengeElapsed = 0
    private var lastFrame: CFTimeInterval?
    private var displayLink: CADisplayLink?
    private var instructionLabel: UILabel?
    private var statusLabel: UILabel?
    private var choiceButtons: [UIButton] = []
    private var sideRow: UIStackView?
    private var swapped = false
    private var challengeStart = Date()
    private var resolved = false

    private func t(_ key: String, _ args: [String: String] = [:]) -> String {
        MessageStrings.t(language, key, args)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = background
        configureStack()
        renderConversationState()
    }

    override func didBecomeActive(with conversation: MSConversation) {
        super.didBecomeActive(with: conversation)
        renderConversationState()
    }

    override func willResignActive(with conversation: MSConversation) {
        stopClock()
        super.willResignActive(with: conversation)
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        renderConversationState()
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        awaitingSend = false
        renderConversationState()
    }

    private func configureStack() {
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
        ])
    }

    private func clear() {
        stopClock()
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        choiceButtons = []
        sideRow = nil
        instructionLabel = nil
        statusLabel = nil
    }

    private func renderConversationState() {
        guard currentChallenge == nil, !awaitingSend else { return }
        clear()
        guard let conversation = activeConversation,
              let selected = conversation.selectedMessage,
              let url = selected.url,
              let decoded = try? MatchCodec.decode(url) else {
            renderStart()
            return
        }
        match = decoded
        let sentByMe = selected.senderParticipantIdentifier == conversation.localParticipantIdentifier
        viewerIsFirst = MessageMatch.viewerIsFirst(stage: decoded.stage, sentByViewer: sentByMe)
        switch decoded.stage {
        case .awaitingReply:
            if sentByMe {
                renderWaiting(decoded, round: decoded.roundIndex)
            } else {
                renderIncoming(decoded)
            }
        case .roundResolved:
            if sentByMe {
                renderWaiting(decoded, round: decoded.roundIndex + 1)
            } else {
                renderRoundResult(decoded)
            }
        case .matchResolved:
            renderFinal(decoded)
        }
    }

    private func renderStart() {
        stack.addArrangedSubview(headline(t("ui.title")))
        stack.addArrangedSubview(body(t("ui.start.body")))
        stack.addArrangedSubview(caption(t("ui.rules"), centered: true))
        stack.addArrangedSubview(actionButton(t("ui.start.button"), color: yellow, selector: #selector(startMatch)))
        stack.addArrangedSubview(caption(t("ui.start.caption"), centered: true))
    }

    private func renderIncoming(_ match: MessageMatch) {
        let round = "\(match.roundIndex + 1)"
        stack.addArrangedSubview(headline(t("ui.incoming.title", ["n": round])))
        if match.roundIndex > 0 { stack.addArrangedSubview(scoreboard(match)) }
        stack.addArrangedSubview(body(t("ui.incoming.body")))
        stack.addArrangedSubview(actionButton(t("ui.incoming.button", ["n": round]), color: pink, selector: #selector(playReply)))
        stack.addArrangedSubview(caption(t("ui.rules"), centered: true))
    }

    private func renderWaiting(_ match: MessageMatch, round: Int) {
        stack.addArrangedSubview(headline(t("ui.waiting.title")))
        stack.addArrangedSubview(scoreboard(match))
        stack.addArrangedSubview(body(t("ui.waiting.body", ["n": "\(min(round + 1, MessageMatch.roundCount))"])))
        stack.addArrangedSubview(caption(t("ui.waiting.caption"), centered: true))
    }

    private func renderRoundResult(_ match: MessageMatch) {
        guard let round = match.currentRound else { renderStart(); return }
        stack.addArrangedSubview(headline(t("ui.round_done", ["n": "\(round.index + 1)"])))
        stack.addArrangedSubview(body(verdict(round)))
        stack.addArrangedSubview(scoreboard(match))
        stack.addArrangedSubview(actionButton(t("ui.next.button", ["n": "\(round.index + 2)"]), color: yellow, selector: #selector(playNextRound)))
    }

    private func renderFinal(_ match: MessageMatch) {
        stack.addArrangedSubview(headline(t("ui.final")))
        stack.addArrangedSubview(scoreboard(match))
        let score = match.score(viewerIsFirst: viewerIsFirst)
        let line = score.mine == score.theirs ? t("ui.final.tie")
            : score.mine > score.theirs ? t("ui.final.won") : t("ui.final.lost")
        stack.addArrangedSubview(body(line))
        stack.addArrangedSubview(actionButton(t("ui.rematch"), color: pink, selector: #selector(startMatch)))
    }

    @objc private func startMatch() {
        var seed = UInt64.random(in: 1...UInt64.max)
        if seed == 0 { seed = 1 }
        match = MessageMatch(seed: seed)
        playMode = .firstNew
        viewerIsFirst = true
        beginPlay()
    }

    @objc private func playReply() {
        playMode = .second
        viewerIsFirst = false
        beginPlay()
    }

    @objc private func playNextRound() {
        playMode = .firstNext
        viewerIsFirst = true
        beginPlay()
    }

    private func beginPlay() {
        guard let match else { return }
        awaitingSend = false
        requestPresentationStyle(.expanded)
        generator = StupidChallengeGenerator(matchSeed: match.seed, language: language)
        streak = 0
        elapsedMilliseconds = 0
        currentChallenge = nil
        showChallenge()
    }

    /// Round index the current play is for (advanceRound bumps it later).
    private var playingRound: Int {
        guard let match else { return 0 }
        return playMode == .firstNext ? match.roundIndex + 1 : match.roundIndex
    }

    private func showChallenge() {
        guard let generator else { return }
        clear()
        resolved = false
        swapped = false
        challengeElapsed = 0
        lastFrame = nil
        challengeStart = Date()
        let challenge = generator.challenge(round: playingRound, streak: streak)
        currentChallenge = challenge

        let top = caption(t("ui.hud", ["r": "\(playingRound + 1)", "n": "\(streak)"]), centered: true)
        top.textColor = yellow
        stack.addArrangedSubview(top)
        let instruction = headline(challenge.instruction)
        instructionLabel = instruction
        stack.addArrangedSubview(instruction)

        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 10
        for rowStart in stride(from: 0, to: challenge.choices.count, by: 2) {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 10
            for index in rowStart..<min(rowStart + 2, challenge.choices.count) {
                let button = choiceButton(challenge, index: index)
                row.addArrangedSubview(button)
                choiceButtons.append(button)
            }
            if case .side = challenge.behavior { sideRow = row }
            grid.addArrangedSubview(row)
        }
        stack.addArrangedSubview(grid)
        let status = caption(t("ui.hint"), centered: true)
        statusLabel = status
        stack.addArrangedSubview(status)
        startClock()
    }

    private func choiceButton(_ challenge: StupidChallenge, index: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(challenge.choices[index], for: .normal)
        let scale = challenge.scales[index]
        let glyph = challenge.choices[index] == "●" || challenge.choices[index] == "○"
        button.titleLabel?.font = .systemFont(ofSize: (glyph ? 46 : 24) * scale, weight: .black)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.5
        let fill = challenge.tints[index].map(color(for:)) ?? ink
        button.backgroundColor = fill
        button.setTitleColor(fill == yellow || fill == ink ? background : .white, for: .normal)
        button.layer.cornerRadius = 18
        button.tag = index
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 74).isActive = true
        button.addTarget(self, action: #selector(choiceTapped(_:)), for: .touchUpInside)
        return button
    }

    private func color(for tint: StupidChallenge.Tint) -> UIColor {
        switch tint {
        case .red: return red
        case .blue: return blue
        case .green: return green
        case .yellow: return yellow
        case .orange: return orange
        }
    }

    @objc private func choiceTapped(_ sender: UIButton) {
        guard let challenge = currentChallenge, !resolved else { return }
        switch challenge.behavior {
        case .choose(let correctIndex):
            sender.tag == correctIndex ? passChallenge() : failChallenge(challenge.failLine)
        case .avoid(let forbiddenIndex):
            sender.tag == forbiddenIndex ? failChallenge(challenge.failLine) : passChallenge()
        case .doNothing:
            failChallenge(challenge.failLine)
        case .waitForGreen(let delay):
            challengeElapsed >= delay ? passChallenge() : failChallenge(challenge.failLine)
        case .side(let wantLeft, _):
            let tappedLeft = sideRow?.arrangedSubviews.first === sender
            tappedLeft == wantLeft ? passChallenge() : failChallenge(challenge.failLine)
        }
    }

    private func startClock() {
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopClock() {
        displayLink?.invalidate()
        displayLink = nil
        lastFrame = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard let challenge = currentChallenge, !resolved else { return }
        let delta = lastFrame.map { Int((link.timestamp - $0) * 1_000) } ?? 0
        lastFrame = link.timestamp
        challengeElapsed += max(0, delta)
        switch challenge.behavior {
        case .waitForGreen(let delay) where challengeElapsed >= delay:
            choiceButtons.first?.backgroundColor = green
            choiceButtons.first?.setTitle(t("c.wait_green.go"), for: .normal)
        case .side(_, let swapAt) where !swapped && challengeElapsed >= swapAt:
            swapped = true
            if let row = sideRow, let first = row.arrangedSubviews.first {
                row.removeArrangedSubview(first)
                row.addArrangedSubview(first)
            }
        default:
            break
        }
        if challengeElapsed >= challenge.durationMilliseconds {
            if case .doNothing = challenge.behavior {
                passChallenge()
            } else {
                failChallenge(challenge.timeoutLine)
            }
        }
    }

    private func passChallenge() {
        guard !resolved else { return }
        resolved = true
        stopClock()
        elapsedMilliseconds += Int(Date().timeIntervalSince(challengeStart) * 1_000)
        streak += 1
        view.backgroundColor = green
        choiceButtons.forEach { $0.isEnabled = false }
        instructionLabel?.text = "✓ \(streak)"
        statusLabel?.text = t("ui.correct")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { [weak self] in
            self?.view.backgroundColor = self?.background
            self?.currentChallenge = nil
            self?.showChallenge()
        }
    }

    private func failChallenge(_ line: String) {
        guard !resolved else { return }
        resolved = true
        stopClock()
        elapsedMilliseconds += Int(Date().timeIntervalSince(challengeStart) * 1_000)
        view.backgroundColor = red
        instructionLabel?.text = line
        choiceButtons.forEach { $0.isEnabled = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self] in
            self?.view.backgroundColor = self?.background
            self?.finishStreak()
        }
    }

    private func finishStreak() {
        guard var match, let playMode else { return }
        currentChallenge = nil
        awaitingSend = true
        let result = DuelResult(streak: streak, elapsedMilliseconds: elapsedMilliseconds)
        switch playMode {
        case .firstNew: match.recordFirst(result)
        case .firstNext: match.advanceRound(with: result)
        case .second: match.recordSecond(result)
        }
        self.match = match
        clear()
        stack.addArrangedSubview(headline(t("ui.streak", ["n": "\(streak)"])))
        if playMode == .second, let round = match.currentRound {
            stack.addArrangedSubview(body(verdict(round)))
            stack.addArrangedSubview(scoreboard(match))
        } else {
            stack.addArrangedSubview(body(t("ui.streak.hidden")))
            if match.roundIndex > 0 { stack.addArrangedSubview(scoreboard(match)) }
        }
        let send = match.stage == .matchResolved ? t("ui.send.final") : t("ui.send")
        stack.addArrangedSubview(actionButton(send, color: yellow, selector: #selector(insertMatchMessage)))
    }

    @objc private func insertMatchMessage() {
        guard let match, let conversation = activeConversation else { return }
        do {
            let session = conversation.selectedMessage?.session ?? MSSession()
            let message = MSMessage(session: session)
            message.url = try MatchCodec.encode(match)
            message.layout = cardLayout(match)
            message.summaryText = summary(match)
            message.accessibilityLabel = summary(match)
            conversation.insert(message) { [weak self] error in
                DispatchQueue.main.async {
                    if error == nil {
                        self?.awaitingSend = false
                        self?.dismiss()
                    } else {
                        self?.renderError(self?.t("ui.error.insert") ?? "")
                    }
                }
            }
        } catch {
            renderError(t("ui.error.state"))
        }
    }

    // MARK: - Transcript card
    //
    // The card is identical on both devices, so it speaks as the sender:
    // "ME 1 – 0 YOU" reads correctly for whoever looks at the bubble. The
    // sender of an awaitingReply message is the first player; every
    // resolved message is sent by the second.

    private func senderScore(_ match: MessageMatch) -> (me: Int, you: Int) {
        let score = match.score(viewerIsFirst: match.stage == .awaitingReply)
        return (score.mine, score.theirs)
    }

    private func cardLayout(_ match: MessageMatch) -> MSMessageTemplateLayout {
        let layout = MSMessageTemplateLayout()
        let score = senderScore(match)
        layout.image = cardImage(match)
        layout.caption = t("ui.title")
        layout.subcaption = summary(match)
        layout.trailingCaption = t("card.score", ["me": "\(score.me)", "you": "\(score.you)"])
        return layout
    }

    private func cardImage(_ match: MessageMatch) -> UIImage {
        let size = CGSize(width: 640, height: 360)
        let score = senderScore(match)
        return UIGraphicsImageRenderer(size: size).image { context in
            background.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            yellow.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 42, y: 42, width: 108, height: 108))
            pink.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 88, y: 76, width: 108, height: 108))
            let title = match.stage == .matchResolved ? t("card.final") : t("card.round", ["n": "\(match.roundIndex + 1)"])
            title.draw(in: CGRect(x: 224, y: 62, width: 400, height: 90), withAttributes: [
                .font: UIFont.systemFont(ofSize: 68, weight: .black),
                .foregroundColor: ink,
            ])
            let subtitle = match.stage == .awaitingReply ? t("card.your_turn") : t("card.results")
            subtitle.draw(in: CGRect(x: 226, y: 160, width: 400, height: 44), withAttributes: [
                .font: UIFont.systemFont(ofSize: 30, weight: .bold),
                .foregroundColor: yellow,
            ])
            let line = t("card.score", ["me": "\(score.me)", "you": "\(score.you)"])
            line.draw(in: CGRect(x: 42, y: 240, width: 560, height: 80), withAttributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 56, weight: .black),
                .foregroundColor: ink,
            ])
        }
    }

    private func summary(_ match: MessageMatch) -> String {
        let score = senderScore(match)
        switch match.stage {
        case .awaitingReply:
            return t("card.summary.turn", ["n": "\(match.roundIndex + 1)"])
        case .roundResolved:
            guard let round = match.currentRound, let second = round.second else { return t("card.results") }
            // Sender is the second player here.
            return t("card.summary.round", ["n": "\(round.index + 1)", "me": "\(second.streak)", "you": "\(round.first.streak)",
                                            "sme": "\(score.me)", "syou": "\(score.you)"])
        case .matchResolved:
            return t("card.summary.final", ["me": "\(score.me)", "you": "\(score.you)"])
        }
    }

    // MARK: - Scoreboard

    /// One line explaining who took the round's point, from this device.
    private func verdict(_ round: DuelRound) -> String {
        guard let winner = round.winner else { return t("ui.streak.hidden") }
        if winner == .tie { return t("ui.verdict.tie") }
        let mine = (winner == .first) == viewerIsFirst
        let point = mine ? t("ui.verdict.you") : t("ui.verdict.rival")
        return round.decidedByTime ? "\(t("ui.verdict.faster")) \(point)" : point
    }

    /// "YOU 1 – 0 RIVAL" plus one row per played round with both streaks.
    private func scoreboard(_ match: MessageMatch) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 6

        let score = match.score(viewerIsFirst: viewerIsFirst)
        let header = UIStackView()
        header.axis = .horizontal
        header.distribution = .fillEqually
        header.addArrangedSubview(scoreColumn(t("ui.you"), score.mine, color: yellow))
        header.addArrangedSubview(scoreColumn(t("ui.rival"), score.theirs, color: pink))
        container.addArrangedSubview(header)

        for round in match.rounds {
            let mine = viewerIsFirst ? round.first : round.second
            let theirs = viewerIsFirst ? round.second : round.first
            let outcome: String
            switch round.winner {
            case nil: outcome = t("ui.round.pending")
            case .tie?: outcome = t("ui.round.tie")
            case let winner?: outcome = (winner == .first) == viewerIsFirst ? t("ui.round.you") : t("ui.round.rival")
            }
            let label = caption("\(t("ui.round.short", ["n": "\(round.index + 1)"]))    \(mine.map { "\($0.streak)" } ?? "?")  –  \(theirs.map { "\($0.streak)" } ?? "?")    \(outcome)", centered: true)
            label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .bold)
            container.addArrangedSubview(label)
        }
        return container
    }

    private func scoreColumn(_ name: String, _ value: Int, color: UIColor) -> UIView {
        let column = UIStackView()
        column.axis = .vertical
        column.alignment = .center
        let number = UILabel()
        number.text = "\(value)"
        number.font = .monospacedDigitSystemFont(ofSize: 48, weight: .black)
        number.textColor = color
        let label = UILabel()
        label.text = name
        label.font = .systemFont(ofSize: 13, weight: .black)
        label.textColor = color
        column.addArrangedSubview(number)
        column.addArrangedSubview(label)
        return column
    }

    // MARK: - Building blocks

    private func headline(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = ink
        label.font = .systemFont(ofSize: 38, weight: .black)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.45
        return label
    }

    private func body(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = ink
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }

    private func caption(_ text: String, centered: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = ink.withAlphaComponent(0.62)
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.numberOfLines = 0
        if centered { label.textAlignment = .center }
        return label
    }

    private func actionButton(_ title: String, color: UIColor, selector: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .black)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.6
        button.setTitleColor(background, for: .normal)
        button.backgroundColor = color
        button.layer.cornerRadius = 18
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 58).isActive = true
        button.addTarget(self, action: selector, for: .touchUpInside)
        return button
    }

    private func renderError(_ text: String) {
        currentChallenge = nil
        awaitingSend = false
        clear()
        stack.addArrangedSubview(headline(text))
        stack.addArrangedSubview(actionButton(t("ui.error.restart"), color: yellow, selector: #selector(startMatch)))
    }
}
