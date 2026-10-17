import Foundation

/// Anti-repetition memory for the presenter (see [[Multiplayer Presenter]] →
/// "Repetition guard"). It remembers *what was said*, not ids: two lines with
/// different ids but the same words, or the same punchline, are one joke.
///
/// - Every line cools down for `cooldownBeats` beats — moments the host
///   could speak, whether or not it did — across matches too.
/// - Lines the caller marks `oncePerMatch` (the named, per-player jokes) are
///   spent until `beginMatch()`.
/// - When nothing is allowed the engine stays silent: silence beats a repeat.
struct PresenterLineHistory {
    /// Beats that must pass before the same joke may return.
    static let cooldownBeats = 6

    private var beat = 0
    private var lastBeat: [String: Int] = [:]
    private var spentThisMatch: Set<String> = []

    mutating func beginMatch() {
        spentThisMatch = []
    }

    /// [text] is the copy *before* the player's name is filled in (`{name}`
    /// still literal), so the same joke aimed at someone else still counts.
    func allows(_ text: String, oncePerMatch: Bool) -> Bool {
        Self.signatures(of: text).allSatisfy { signature in
            if oncePerMatch, spentThisMatch.contains(signature) { return false }
            guard let last = lastBeat[signature] else { return true }
            return beat - last >= Self.cooldownBeats
        }
    }

    /// One presenter beat passed (a round result, the lobby, game end).
    mutating func advance() {
        beat += 1
    }

    mutating func record(_ text: String) {
        for signature in Self.signatures(of: text) {
            lastBeat[signature] = beat
            spentThisMatch.insert(signature)
        }
    }

    /// The whole line and, for multi-sentence lines, its final sentence —
    /// the punch. Letters and digits only, placeholders removed, so
    /// punctuation, spacing or a different name never make a joke "new".
    static func signatures(of text: String) -> Set<String> {
        let bare = text.replacingOccurrences(of: "{name}", with: " ").replacingOccurrences(of: "{title}", with: " ")
        let sentences = bare
            .split(whereSeparator: { ".?!¿¡".contains($0) })
            .map(normalize)
            .filter { !$0.isEmpty }
        guard !sentences.isEmpty else { return [] }
        var result: Set<String> = [sentences.joined(separator: " ")]
        if sentences.count > 1 { result.insert(sentences[sentences.count - 1]) }
        return result
    }

    private static func normalize(_ fragment: Substring) -> String {
        fragment
            .uppercased()
            .map { $0.isLetter || $0.isNumber ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
            .split(separator: " ")
            .joined(separator: " ")
    }
}
