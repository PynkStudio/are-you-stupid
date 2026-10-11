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

    private var stack = UIStackView()
    private var match: MessageMatch?
    private var playMode: PlayMode?
    private var generator: StupidChallengeGenerator?
    private var currentChallenge: StupidChallenge?
    private var streak = 0
    private var elapsedMilliseconds = 0
    private var challengeElapsed = 0
    private var lastFrame: CFTimeInterval?
    private var displayLink: CADisplayLink?
    private var instructionLabel: UILabel?
    private var statusLabel: UILabel?
    private var choiceButtons: [UIButton] = []
    private var challengeStart = Date()
    private var resolved = false

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
        instructionLabel = nil
        statusLabel = nil
    }

    private func renderConversationState() {
        guard currentChallenge == nil else { return }
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
        switch decoded.stage {
        case .awaitingReply:
            if sentByMe {
                renderWaiting(round: decoded.roundIndex)
            } else {
                renderIncoming(decoded)
            }
        case .roundResolved:
            if sentByMe {
                renderWaiting(round: decoded.roundIndex + 1)
            } else {
                renderRoundResult(decoded)
            }
        case .matchResolved:
            renderFinal(decoded, sentByMe: sentByMe)
        }
    }

    private func renderStart() {
        stack.addArrangedSubview(headline("STUPID STREAK"))
        stack.addArrangedSubview(body("Same traps. Same order. Three increasingly stupid rounds."))
        let start = actionButton("START A 1V1 CHALLENGE", color: yellow, selector: #selector(startMatch))
        stack.addArrangedSubview(start)
        stack.addArrangedSubview(caption("Best in a one-to-one iMessage conversation."))
    }

    private func renderIncoming(_ match: MessageMatch) {
        stack.addArrangedSubview(headline("ROUND \(match.roundIndex + 1) IS WAITING"))
        stack.addArrangedSubview(body("Your opponent already played. Their streak stays hidden until you finish."))
        stack.addArrangedSubview(actionButton("PLAY THE SAME STREAK", color: pink, selector: #selector(playReply)))
    }

    private func renderWaiting(round: Int) {
        stack.addArrangedSubview(headline("NOW WE WAIT"))
        stack.addArrangedSubview(body("Round \(min(round + 1, MessageMatch.roundCount)) is in the chat. Their score is hidden until they play."))
        stack.addArrangedSubview(caption("You can close this. The message keeps the match."))
    }

    private func renderRoundResult(_ match: MessageMatch) {
        guard let round = match.currentRound else { renderStart(); return }
        stack.addArrangedSubview(headline("ROUND \(round.index + 1) DONE"))
        stack.addArrangedSubview(scoreboard(match))
        stack.addArrangedSubview(body(roundLine(round)))
        stack.addArrangedSubview(actionButton("PLAY ROUND \(round.index + 2)", color: yellow, selector: #selector(playNextRound)))
    }

    private func renderFinal(_ match: MessageMatch, sentByMe: Bool) {
        stack.addArrangedSubview(headline("THAT WAS THE MATCH"))
        stack.addArrangedSubview(scoreboard(match))
        let score = match.score
        let line: String
        if score.first == score.second {
            line = "YOU ARE EQUALLY STUPID. BEAUTIFUL."
        } else {
            let senderWon = score.second > score.first
            line = senderWon == sentByMe ? "YOU ARE OFFICIALLY LESS STUPID." : "THE OTHER PERSON IS LESS STUPID."
        }
        stack.addArrangedSubview(body(line))
        stack.addArrangedSubview(actionButton("REMATCH", color: pink, selector: #selector(startMatch)))
    }

    @objc private func startMatch() {
        var seed = UInt64.random(in: 1...UInt64.max)
        if seed == 0 { seed = 1 }
        match = MessageMatch(seed: seed)
        playMode = .firstNew
        beginPlay()
    }

    @objc private func playReply() {
        playMode = .second
        beginPlay()
    }

    @objc private func playNextRound() {
        playMode = .firstNext
        beginPlay()
    }

    private func beginPlay() {
        guard let match else { return }
        requestPresentationStyle(.expanded)
        generator = StupidChallengeGenerator(matchSeed: match.seed)
        streak = 0
        elapsedMilliseconds = 0
        currentChallenge = nil
        showChallenge()
    }

    private func showChallenge() {
        guard let match, let generator else { return }
        clear()
        resolved = false
        challengeElapsed = 0
        lastFrame = nil
        challengeStart = Date()
        let challenge = generator.challenge(round: match.roundIndex, streak: streak)
        currentChallenge = challenge

        let top = caption("ROUND \(match.roundIndex + 1)   •   STREAK \(streak)")
        top.textColor = yellow
        stack.addArrangedSubview(top)
        let instruction = headline(challenge.instruction)
        instructionLabel = instruction
        stack.addArrangedSubview(instruction)

        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 10
        let rows = stride(from: 0, to: challenge.choices.count, by: 2)
        for rowStart in rows {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 10
            for index in rowStart..<min(rowStart + 2, challenge.choices.count) {
                let button = UIButton(type: .system)
                button.setTitle(challenge.choices[index], for: .normal)
                button.titleLabel?.font = .systemFont(ofSize: 24, weight: .black)
                button.setTitleColor(background, for: .normal)
                button.backgroundColor = ink
                button.layer.cornerRadius = 18
                button.tag = index
                button.heightAnchor.constraint(greaterThanOrEqualToConstant: 74).isActive = true
                button.addTarget(self, action: #selector(choiceTapped(_:)), for: .touchUpInside)
                row.addArrangedSubview(button)
                choiceButtons.append(button)
            }
            grid.addArrangedSubview(row)
        }
        stack.addArrangedSubview(grid)
        let status = caption("DON'T OVERTHINK IT.")
        status.textAlignment = .center
        statusLabel = status
        stack.addArrangedSubview(status)
        startClock()
    }

    @objc private func choiceTapped(_ sender: UIButton) {
        guard let challenge = currentChallenge, !resolved else { return }
        switch challenge.behavior {
        case .choose(let correctIndex):
            sender.tag == correctIndex ? passChallenge() : failChallenge(challenge.failLine)
        case .doNothing:
            failChallenge(challenge.failLine)
        case .waitForGreen(let delay):
            challengeElapsed >= delay ? passChallenge() : failChallenge(challenge.failLine)
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
        if case .waitForGreen(let delay) = challenge.behavior, challengeElapsed >= delay {
            choiceButtons.first?.backgroundColor = green
            choiceButtons.first?.setTitle("TAP", for: .normal)
        }
        if challengeElapsed >= challenge.durationMilliseconds {
            if case .doNothing = challenge.behavior {
                passChallenge()
            } else {
                failChallenge("TIME RAN OUT. IT WASN'T HIDING.")
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
        statusLabel?.text = "SOMEHOW CORRECT."
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
        let result = DuelResult(streak: streak, elapsedMilliseconds: elapsedMilliseconds)
        switch playMode {
        case .firstNew: match.recordFirst(result)
        case .firstNext: match.advanceRound(with: result)
        case .second: match.recordSecond(result)
        }
        self.match = match
        clear()
        stack.addArrangedSubview(headline("STREAK: \(streak)"))
        if playMode == .second {
            stack.addArrangedSubview(scoreboard(match))
        } else {
            stack.addArrangedSubview(body("Their result stays hidden until they play."))
        }
        stack.addArrangedSubview(actionButton(match.stage == .matchResolved ? "SEND FINAL RESULT" : "SEND TO THE CHAT", color: yellow, selector: #selector(insertMatchMessage)))
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
                        self?.dismiss()
                    } else {
                        self?.renderError("COULDN'T INSERT THE CHALLENGE.")
                    }
                }
            }
        } catch {
            renderError("THE MATCH STATE BROKE. IMPRESSIVE.")
        }
    }

    private func cardLayout(_ match: MessageMatch) -> MSMessageTemplateLayout {
        let layout = MSMessageTemplateLayout()
        layout.image = cardImage(match)
        layout.caption = "STUPID STREAK"
        layout.subcaption = summary(match)
        layout.trailingCaption = "\(match.score.first)–\(match.score.second)"
        return layout
    }

    private func cardImage(_ match: MessageMatch) -> UIImage {
        let size = CGSize(width: 640, height: 360)
        return UIGraphicsImageRenderer(size: size).image { context in
            background.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            yellow.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 42, y: 42, width: 108, height: 108))
            pink.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 88, y: 76, width: 108, height: 108))
            let title = match.stage == .matchResolved ? "FINAL" : "ROUND \(match.roundIndex + 1)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 72, weight: .black),
                .foregroundColor: ink,
            ]
            title.draw(at: CGPoint(x: 224, y: 70), withAttributes: attributes)
            let subtitle = match.stage == .awaitingReply ? "YOUR TURN. PROBABLY." : "RESULTS ARE IN."
            subtitle.draw(at: CGPoint(x: 226, y: 172), withAttributes: [
                .font: UIFont.systemFont(ofSize: 30, weight: .bold),
                .foregroundColor: yellow,
            ])
        }
    }

    private func summary(_ match: MessageMatch) -> String {
        switch match.stage {
        case .awaitingReply: return "Round \(match.roundIndex + 1): your turn"
        case .roundResolved: return "Round \(match.roundIndex + 1) complete — open for results"
        case .matchResolved: return "Final score \(match.score.first)–\(match.score.second)"
        }
    }

    private func roundLine(_ round: DuelRound) -> String {
        switch round.winner {
        case .first: return "FIRST PLAYER WAS LESS STUPID."
        case .second: return "SECOND PLAYER WAS LESS STUPID."
        case .tie: return "AN EQUALLY STUPID ROUND."
        case nil: return "SOMEONE STILL HAS TO PLAY."
        }
    }

    private func scoreboard(_ match: MessageMatch) -> UIView {
        let label = UILabel()
        label.text = "\(match.score.first)     —     \(match.score.second)"
        label.textAlignment = .center
        label.font = .monospacedDigitSystemFont(ofSize: 48, weight: .black)
        label.textColor = yellow
        return label
    }

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

    private func caption(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = ink.withAlphaComponent(0.62)
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.numberOfLines = 0
        return label
    }

    private func actionButton(_ title: String, color: UIColor, selector: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .black)
        button.setTitleColor(background, for: .normal)
        button.backgroundColor = color
        button.layer.cornerRadius = 18
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 58).isActive = true
        button.addTarget(self, action: selector, for: .touchUpInside)
        return button
    }

    private func renderError(_ text: String) {
        currentChallenge = nil
        clear()
        stack.addArrangedSubview(headline(text))
        stack.addArrangedSubview(actionButton("START OVER", color: yellow, selector: #selector(startMatch)))
    }
}
