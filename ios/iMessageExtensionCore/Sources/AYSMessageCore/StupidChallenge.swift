import Foundation

public struct StupidChallenge: Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case tapColor, dontTapColor, tapNumber, math, oddOneOut, opposite, biggest, doNothing, waitForGreen, leftRight
    }

    public enum Behavior: Equatable, Sendable {
        /// Tap the button at `correctIndex`.
        case choose(correctIndex: Int)
        /// Tap anything except the button at `forbiddenIndex`; timing out fails.
        case avoid(forbiddenIndex: Int)
        /// Tap nothing until the timer runs out.
        case doNothing
        /// Tap the single button only once it turns green.
        case waitForGreen(delayMilliseconds: Int)
        /// Tap the button on the named screen side; the two buttons swap
        /// places after `swapAtMilliseconds` (port of `left_right_swap`).
        case side(wantLeft: Bool, swapAtMilliseconds: Int)
    }

    /// Fill colors for a button; `nil` means the default ink button.
    public enum Tint: String, Equatable, Sendable { case red, blue, green, yellow, orange }

    public let kind: Kind
    public let instruction: String
    public let choices: [String]
    public let tints: [Tint?]
    /// Relative glyph size per button (1 = normal).
    public let scales: [Double]
    public let behavior: Behavior
    public let durationMilliseconds: Int
    public let failLine: String
    public let timeoutLine: String
}

/// Deterministic per match: both players get the same kinds, answers and
/// timing for every (round, streak), whatever language each device shows.
public struct StupidChallengeGenerator: Sendable {
    private let matchSeed: UInt64
    private let language: MessageLanguage

    public init(matchSeed: UInt64, language: MessageLanguage = .en) {
        self.matchSeed = matchSeed
        self.language = language
    }

    public func challenge(round: Int, streak: Int) -> StupidChallenge {
        // Walk the round from the start so each pick can see the previous
        // two kinds: never the same family twice in a row, and not the one
        // from two steps back either when the pool allows it.
        var history: [StupidChallenge.Kind] = []
        var result: StupidChallenge?
        for index in 0...max(0, streak) {
            var rng = SplitMix64(seed: matchSeed &+ UInt64(round &* 10_007 + index &* 97))
            let kind = Self.pick(round: round, streak: index, history: history, rng: &rng)
            history.append(kind)
            if index == streak {
                result = Builder(language: language).build(kind, round: round, streak: index, rng: &rng)
            }
        }
        return result!
    }

    static func pool(round: Int, streak: Int) -> [StupidChallenge.Kind] {
        switch min(3, round + streak / 3) {
        case 0: return [.tapColor, .tapNumber, .math, .oddOneOut, .biggest]
        case 1: return [.tapColor, .tapNumber, .math, .oddOneOut, .biggest, .opposite, .dontTapColor]
        case 2: return [.math, .oddOneOut, .opposite, .biggest, .doNothing, .dontTapColor, .waitForGreen, .leftRight]
        default: return [.opposite, .biggest, .doNothing, .dontTapColor, .waitForGreen, .leftRight, .math, .oddOneOut]
        }
    }

    private static func pick(round: Int, streak: Int, history: [StupidChallenge.Kind], rng: inout SplitMix64) -> StupidChallenge.Kind {
        let pool = pool(round: round, streak: streak)
        var candidates = pool.filter { !history.suffix(2).contains($0) }
        if candidates.isEmpty { candidates = pool.filter { $0 != history.last } }
        if candidates.isEmpty { candidates = pool }
        return candidates[rng.int(candidates.count)]
    }
}

private struct Builder {
    let language: MessageLanguage

    private func t(_ key: String, _ args: [String: String] = [:]) -> String {
        MessageStrings.t(language, key, args)
    }

    func build(_ kind: StupidChallenge.Kind, round: Int, streak: Int, rng: inout SplitMix64) -> StupidChallenge {
        let time = max(1_150, 3_900 - round * 600 - streak * (120 + round * 35))
        let timeout = t("c.timeout")
        switch kind {
        case .tapColor:
            let colors = shuffled(Self.colors, rng: &rng)
            let correct = rng.int(colors.count)
            let name = t("color.\(colors[correct].rawValue)")
            return choice(kind, t("c.tap_color", ["color": name]), colors.map { t("color.\($0.rawValue)") },
                          tints: colors, correct: correct, time: time, fail: t("c.tap_color.fail", ["color": name]))
        case .dontTapColor:
            let colors = shuffled(Self.colors, rng: &rng)
            let forbidden = rng.int(colors.count)
            let name = t("color.\(colors[forbidden].rawValue)")
            return .init(kind: kind, instruction: t("c.dont_tap_color", ["color": name]),
                         choices: colors.map { t("color.\($0.rawValue)") }, tints: colors, scales: ones(4),
                         behavior: .avoid(forbiddenIndex: forbidden), durationMilliseconds: time,
                         failLine: t("c.dont_tap_color.fail"), timeoutLine: t("c.dont_tap_color.late"))
        case .tapNumber:
            let values = shuffled([1, 2, 3, 4], rng: &rng)
            let wanted = values[rng.int(values.count)]
            return choice(kind, t("c.tap_number", ["n": "\(wanted)"]), values.map(String.init),
                          correct: values.firstIndex(of: wanted)!, time: time, fail: t("c.tap_number.fail"))
        case .math:
            let a = 2 + rng.int(7), b = 1 + rng.int(6), answer = a + b
            let values = shuffled([answer, answer + 1, answer - 1, answer + 2], rng: &rng)
            return choice(kind, t("c.math", ["a": "\(a)", "b": "\(b)"]), values.map(String.init),
                          correct: values.firstIndex(of: answer)!, time: time, fail: t("c.math.fail"))
        case .oddOneOut:
            let odd = rng.int(4)
            return choice(kind, t("c.odd"), (0..<4).map { $0 == odd ? "●" : "○" },
                          correct: odd, time: time, fail: t("c.odd.fail"))
        case .opposite:
            // Always names its word: "the opposite" never refers back to a
            // previous challenge the player may not have seen.
            let pairs = MessageStrings.oppositePairs[language] ?? MessageStrings.oppositePairs[.en]!
            let pair = pairs[rng.int(pairs.count)]
            let showFirst = rng.bool()
            let shown = showFirst ? pair.0 : pair.1
            let answer = showFirst ? pair.1 : pair.0
            let options = rng.bool() ? [pair.0, pair.1] : [pair.1, pair.0]
            return choice(kind, t("c.opposite", ["word": shown]), options,
                          correct: options.firstIndex(of: answer)!, time: time, fail: t("c.opposite.fail"))
        case .biggest:
            let sizes = round == 0 ? [1.0, 0.78, 0.62, 0.48] : [1.0, 0.88, 0.78, 0.68]
            let scales = shuffled(sizes, rng: &rng)
            return .init(kind: kind, instruction: t("c.biggest"), choices: Array(repeating: "●", count: 4),
                         tints: Array(repeating: nil, count: 4), scales: scales,
                         behavior: .choose(correctIndex: scales.firstIndex(of: 1.0)!), durationMilliseconds: time,
                         failLine: t("c.biggest.fail"), timeoutLine: timeout)
        case .doNothing:
            let bait = t("c.dont_tap.bait")
            return .init(kind: kind, instruction: t("c.dont_tap"), choices: [bait, bait], tints: [nil, nil],
                         scales: ones(2), behavior: .doNothing, durationMilliseconds: max(1_300, time - 500),
                         failLine: t("c.dont_tap.fail"), timeoutLine: timeout)
        case .waitForGreen:
            let delay = 650 + rng.int(850)
            return .init(kind: kind, instruction: t("c.wait_green"), choices: [t("c.wait_green.button")], tints: [nil],
                         scales: ones(1), behavior: .waitForGreen(delayMilliseconds: delay),
                         durationMilliseconds: delay + 1_100, failLine: t("c.wait_green.fail"), timeoutLine: timeout)
        case .leftRight:
            let wantLeft = rng.bool()
            let swapAt = 380 + rng.int(320)
            return .init(kind: kind, instruction: t(wantLeft ? "c.left" : "c.right"), choices: ["", ""],
                         tints: [.blue, .orange], scales: ones(2),
                         behavior: .side(wantLeft: wantLeft, swapAtMilliseconds: swapAt),
                         durationMilliseconds: max(1_400, time - 300), failLine: t("c.left_right.fail"), timeoutLine: timeout)
        }
    }

    private static let colors: [StupidChallenge.Tint] = [.red, .blue, .green, .yellow]

    private func ones(_ count: Int) -> [Double] { Array(repeating: 1, count: count) }

    private func choice(_ kind: StupidChallenge.Kind, _ instruction: String, _ choices: [String],
                        tints: [StupidChallenge.Tint?]? = nil, correct: Int, time: Int, fail: String) -> StupidChallenge {
        .init(kind: kind, instruction: instruction, choices: choices,
              tints: tints ?? Array(repeating: nil, count: choices.count), scales: ones(choices.count),
              behavior: .choose(correctIndex: correct), durationMilliseconds: time,
              failLine: fail, timeoutLine: t("c.timeout"))
    }

    private func shuffled<T>(_ values: [T], rng: inout SplitMix64) -> [T] {
        var result = values
        guard result.count > 1 else { return result }
        for index in stride(from: result.count - 1, through: 1, by: -1) {
            result.swapAt(index, rng.int(index + 1))
        }
        return result
    }
}

struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func int(_ upperBound: Int) -> Int { Int(next() % UInt64(upperBound)) }
    mutating func bool() -> Bool { next() & 1 == 0 }
}
