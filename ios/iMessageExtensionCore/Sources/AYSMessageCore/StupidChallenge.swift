import Foundation

public struct StupidChallenge: Equatable, Sendable {
    public enum Behavior: Equatable, Sendable {
        case choose(correctIndex: Int)
        case doNothing
        case waitForGreen(delayMilliseconds: Int)
    }

    public let instruction: String
    public let choices: [String]
    public let behavior: Behavior
    public let durationMilliseconds: Int
    public let failLine: String
}

public struct StupidChallengeGenerator: Sendable {
    private let matchSeed: UInt64

    public init(matchSeed: UInt64) {
        self.matchSeed = matchSeed
    }

    public func challenge(round: Int, streak: Int) -> StupidChallenge {
        var rng = SplitMix64(seed: matchSeed &+ UInt64(round &* 10_007 + streak &* 97))
        let band = min(3, round + streak / 3)
        let pool: [ChallengeKind]
        switch band {
        case 0: pool = [.tapColor, .tapNumber]
        case 1: pool = [.tapColor, .tapNumber, .math, .oddOneOut]
        case 2: pool = [.math, .oddOneOut, .opposite, .sizeCompare, .doNothing]
        default: pool = [.opposite, .sizeCompare, .doNothing, .waitForGreen, .leftRight]
        }
        return pool[rng.int(pool.count)].build(round: round, streak: streak, rng: &rng)
    }
}

private enum ChallengeKind {
    case tapColor, tapNumber, math, oddOneOut, opposite, sizeCompare, doNothing, waitForGreen, leftRight

    func build(round: Int, streak: Int, rng: inout SplitMix64) -> StupidChallenge {
        let time = max(1_150, 3_900 - round * 600 - streak * (120 + round * 35))
        switch self {
        case .tapColor:
            let colors = ["RED", "BLUE", "GREEN", "YELLOW"]
            let correct = rng.int(colors.count)
            return choice("TAP \(colors[correct])", colors, correct, time, "THAT WASN'T \(colors[correct]).")
        case .tapNumber:
            let values = shuffled([1, 2, 3, 4], rng: &rng)
            let wanted = values[rng.int(values.count)]
            return choice("TAP \(wanted)", values.map(String.init), values.firstIndex(of: wanted)!, time, "YOU MISSED A NUMBER.")
        case .math:
            let a = 2 + rng.int(7), b = 1 + rng.int(6), answer = a + b
            var values = [answer, answer + 1, answer - 1, answer + 2]
            values = shuffled(values, rng: &rng)
            return choice("TAP \(a) + \(b)", values.map(String.init), values.firstIndex(of: answer)!, time, "THE MATH WASN'T THE HARD PART.")
        case .oddOneOut:
            let odd = rng.int(4)
            return choice("TAP THE ODD ONE", (0..<4).map { $0 == odd ? "●" : "○" }, odd, time, "ONE OF THEM WAS FILLED.")
        case .opposite:
            let leftCorrect = rng.bool()
            return choice("TAP THE OPPOSITE", leftCorrect ? ["RIGHT", "LEFT"] : ["LEFT", "RIGHT"], leftCorrect ? 1 : 0, time, "YOU DID EXACTLY WHAT IT SAID.")
        case .sizeCompare:
            let largest = rng.int(4)
            let values = (0..<4).map { $0 == largest ? "BIG" : "small" }
            return choice("TAP THE LARGEST", values, largest, time, "SIZE MATTERS. APPARENTLY.")
        case .doNothing:
            return .init(instruction: "DON'T TAP ANYTHING", choices: ["DON'T", "TAP", "THIS", "BUTTON"], behavior: .doNothing, durationMilliseconds: max(1_300, time - 500), failLine: "YOU TAPPED SOMETHING.")
        case .waitForGreen:
            let delay = 650 + rng.int(850)
            return .init(instruction: "WAIT FOR GREEN", choices: ["WAIT"], behavior: .waitForGreen(delayMilliseconds: delay), durationMilliseconds: delay + 1_100, failLine: "IT WASN'T GREEN YET.")
        case .leftRight:
            let correct = rng.bool() ? 0 : 1
            let instruction = correct == 0 ? "TAP RIGHT" : "TAP LEFT"
            return choice(instruction, ["RIGHT", "LEFT"], correct, time, "SCREEN SIDE. NOT THE WORD.")
        }
    }

    private func choice(_ instruction: String, _ choices: [String], _ correct: Int, _ duration: Int, _ fail: String) -> StupidChallenge {
        .init(instruction: instruction, choices: choices, behavior: .choose(correctIndex: correct), durationMilliseconds: duration, failLine: fail)
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

private struct SplitMix64 {
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
