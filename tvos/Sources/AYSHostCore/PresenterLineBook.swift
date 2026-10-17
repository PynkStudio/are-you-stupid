import Foundation

/// Data-driven presenter copy: universal lines (with pre-recorded clips),
/// spoken-name templates and narrative titles. The same JSON shape is
/// published by the PynkStudio backend (`GET /api/ays/presenter/pack`),
/// bundled with the host as the offline baseline and, last resort, built
/// from `OfflinePresenterPack` in code. See [[Multiplayer Presenter]].
///
/// The book never decides *when* to speak — the engine does. It only says
/// what can be said for a key, so server edits change copy and audio but can
/// never invent game facts.
public struct PresenterLineBook: Codable, Equatable, Sendable {
    /// Highest manifest format this build understands.
    public static let supportedFormat = 1
    static let maxLineCharacters = 180

    public enum Intensity: String, Codable, Sendable {
        case any, neutral, savage

        func allows(_ intensity: PresenterIntensity) -> Bool {
            self == .any || rawValue == intensity.rawValue
        }
    }

    public struct Clip: Codable, Equatable, Hashable, Sendable {
        public let sha256: String
        public let bytes: Int

        public init(sha256: String, bytes: Int) {
            self.sha256 = sha256
            self.bytes = bytes
        }
    }

    public struct Line: Codable, Equatable, Sendable {
        public let id: String
        public let text: String
        public let intensity: Intensity
        public let clip: Clip?

        public init(id: String, text: String, intensity: Intensity = .any, clip: Clip? = nil) {
            self.id = id
            self.text = text
            self.intensity = intensity
            self.clip = clip
        }
    }

    public struct Voice: Codable, Equatable, Sendable {
        public let pack: String
        public let live: String
    }

    public enum Title: String, CaseIterable, Sendable {
        case king, kingUndisputed, doesNotRead

        var fallback: String {
            switch self {
            case .king: return "IL KING"
            case .kingUndisputed: return "IL KING INDISCUSSO"
            case .doesNotRead: return "QUELLO CHE NON LEGGE"
            }
        }
    }

    /// Templates this build can fill, with the placeholders each must use.
    public static let templatePlaceholders: [String: Set<String>] = [
        "title.named": ["name", "title"],
        "title.anonymous": ["title"],
        "gameEnd.named": ["name"],
        "lobby.returning.named": ["name", "title"],
        "lobby.returning.anonymous": ["title"],
        "result.title.king.named": ["name", "title"],
        "result.title.doesNotRead.named": ["name", "title"],
    ].merging(Dictionary(uniqueKeysWithValues: resultTemplateKeys.map { ($0, Set(["name"])) })) { current, _ in current }

    /// Facts the shipped engine can prove and therefore templates the remote
    /// line book is allowed to fill. Unknown template keys are dropped.
    public static let resultTemplateKeys: [String] = {
        let bases = [
            "result.mixed.oneWrong.named",
            "result.player.stillZero",
            "result.player.firstPointLate",
            "result.player.wrongStreak3",
            "result.player.lss.lastLife",
            "result.player.lss.losingLives",
            "result.player.again",
        ]
        let mechanicBases = [
            "result.mixed.oneWrong",
            "result.player.stillZero",
            "result.player.firstPointLate",
            "result.player.wrongStreak3",
        ]
        return bases + mechanicBases.flatMap { base in
            PresenterMechanic.allCases.map { "\(base).mechanic.\($0.rawValue)" }
        }
    }()

    public let format: Int
    public let locale: String
    public let revision: Int
    public let voice: Voice?
    public let lines: [String: [Line]]
    public let templates: [String: [Line]]
    public let titles: [String: String]

    public init(format: Int = PresenterLineBook.supportedFormat, locale: String, revision: Int, voice: Voice? = nil, lines: [String: [Line]], templates: [String: [Line]], titles: [String: String]) {
        self.format = format
        self.locale = locale
        self.revision = revision
        self.voice = voice
        self.lines = lines
        self.templates = templates
        self.titles = titles
    }

    /// The in-code baseline for [locale]: text only, no clips. Always valid.
    /// Unsupported locale codes fall back to English.
    public static func builtIn(locale: String) -> PresenterLineBook {
        let locale = OfflinePresenterPack.supportedLocales.contains(locale) ? locale : "en"
        var lines: [String: [Line]] = [:]
        for (key, variants) in OfflinePresenterPack.lines[locale] ?? OfflinePresenterPack.lines["en"]! {
            lines[key] = variants.enumerated().map { Line(id: "\(key).\($0.offset)", text: $0.element) }
        }
        return PresenterLineBook(
            locale: locale,
            revision: 0,
            lines: lines,
            templates: OfflinePresenterPack.templates[locale]!,
            titles: OfflinePresenterPack.titles[locale]!
        )
    }

    /// Source-compatible Italian default for existing callers and tests.
    public static let builtIn = builtIn(locale: "it")

    /// Decodes a published/bundled manifest and drops everything this build
    /// cannot safely use. Returns nil for an unreadable or too-new format.
    public static func decode(_ data: Data) -> PresenterLineBook? {
        guard let book = try? JSONDecoder().decode(PresenterLineBook.self, from: data),
              book.format <= supportedFormat else { return nil }
        return book.sanitized()
    }

    /// Every clip the book references — what a synced copy must hold locally.
    public var clipHashes: Set<String> {
        Set(lines.values.flatMap { $0 }.compactMap { $0.clip?.sha256 })
    }

    public func variants(for key: String, intensity: PresenterIntensity) -> [Line] {
        (lines[key] ?? []).filter { $0.intensity.allows(intensity) }
    }

    public func title(_ title: Title) -> String {
        titles[title.rawValue]
            ?? OfflinePresenterPack.titles[locale]?[title.rawValue]
            ?? OfflinePresenterPack.titles["en"]![title.rawValue]!
    }

    /// Every template variant allowed at this intensity, unfilled, in book
    /// order. The engine renders them itself so it can skip spent jokes.
    public func templateVariants(for key: String, intensity: PresenterIntensity) -> [Line] {
        (templates[key] ?? []).filter { $0.intensity.allows(intensity) }
    }

    /// Fills the first template variant allowed at this intensity, rotating by
    /// `seed`. Names are data: they are substituted, never interpreted.
    public func render(template key: String, name: String? = nil, title: String? = nil, intensity: PresenterIntensity, seed: Int) -> String? {
        let options = templateVariants(for: key, intensity: intensity)
        guard !options.isEmpty else { return nil }
        var text = options[abs(seed) % options.count].text
        if let name { text = text.replacingOccurrences(of: "{name}", with: name) }
        if let title { text = text.replacingOccurrences(of: "{title}", with: title) }
        return text.contains("{") ? nil : text
    }

    func sanitized() -> PresenterLineBook {
        let cleanLines = lines.compactMapValues { variants -> [Line]? in
            let kept = variants.filter { Self.isValidCopy($0.text) && !$0.text.contains("{") && ($0.clip.map(Self.isValidClip) ?? true) }
            return kept.isEmpty ? nil : kept
        }
        var cleanTemplates: [String: [Line]] = [:]
        for (key, variants) in templates {
            guard let required = Self.templatePlaceholders[key] else { continue }
            let kept = variants.filter { Self.isValidCopy($0.text) && Self.placeholders(in: $0.text) == required }
            if !kept.isEmpty { cleanTemplates[key] = kept }
        }
        let cleanTitles = titles.filter { Title(rawValue: $0.key) != nil && Self.isValidCopy($0.value) && !$0.value.contains("{") }
        return PresenterLineBook(format: format, locale: locale, revision: revision, voice: voice, lines: cleanLines, templates: cleanTemplates, titles: cleanTitles)
    }

    static func isValidCopy(_ text: String) -> Bool {
        let bare = text.replacingOccurrences(of: "{name}", with: "").replacingOccurrences(of: "{title}", with: "")
        return !text.trimmingCharacters(in: .whitespaces).isEmpty
            && text.count <= maxLineCharacters
            && bare == bare.uppercased()
    }

    static func isValidClip(_ clip: Clip) -> Bool {
        clip.bytes > 0 && clip.sha256.count == 64 && clip.sha256.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    static func placeholders(in text: String) -> Set<String> {
        var found: Set<String> = []
        var rest = text[...]
        while let open = rest.firstIndex(of: "{") {
            guard let close = rest[open...].firstIndex(of: "}") else { found.insert("?"); break }
            found.insert(String(rest[rest.index(after: open)..<close]))
            rest = rest[rest.index(after: close)...]
        }
        return found
    }
}
