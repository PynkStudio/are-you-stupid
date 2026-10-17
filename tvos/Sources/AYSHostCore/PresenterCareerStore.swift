import Foundation

/// A returning player's earned title, stored as its language-neutral key so
/// the host says it in the presenter's *current* locale (`IL KING INDISCUSSO`
/// on an Italian board even if it was earned while the board spoke English).
public struct PresenterCareer: Codable, Equatable, Sendable {
    public let title: PresenterLineBook.Title
    public let lastSeen: Date

    public init(title: PresenterLineBook.Title, lastSeen: Date) {
        self.title = title
        self.lastSeen = lastSeen
    }

    private enum CodingKeys: String, CodingKey { case titleKey, title, lastSeen }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lastSeen = try container.decode(Date.self, forKey: .lastSeen)
        if let key = try container.decodeIfPresent(PresenterLineBook.Title.self, forKey: .titleKey) {
            title = key
        } else if let legacy = try container.decodeIfPresent(String.self, forKey: .title),
                  let key = PresenterLineBook.Title(localizedText: legacy) {
            // v1 stored the spoken text in whatever locale was active.
            title = key
        } else {
            throw DecodingError.dataCorruptedError(forKey: .titleKey, in: container, debugDescription: "unknown title")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .titleKey)
        try container.encode(lastSeen, forKey: .lastSeen)
    }
}

public final class PresenterCareerStore {
    private let defaults: UserDefaults
    private let key = "ays.presenter.careers.v1"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func career(for personaId: String, now: Date = Date()) -> PresenterCareer? {
        guard let career = all()[personaId] else { return nil }
        let lifetime: TimeInterval = career.title.isNegative ? 7 * 86_400 : 90 * 86_400
        return now.timeIntervalSince(career.lastSeen) <= lifetime ? career : nil
    }

    public func remember(personaId: String, title: PresenterLineBook.Title, now: Date = Date()) {
        var careers = all()
        careers[personaId] = PresenterCareer(title: title, lastSeen: now)
        if careers.count > 64 {
            for entry in careers.sorted(by: { $0.value.lastSeen < $1.value.lastSeen }).prefix(careers.count - 64) {
                careers.removeValue(forKey: entry.key)
            }
        }
        if let data = try? JSONEncoder().encode(careers) { defaults.set(data, forKey: key) }
    }

    /// Entries that cannot be read (a legacy title in no known wording) are
    /// dropped rather than spoken in the wrong language.
    private func all() -> [String: PresenterCareer] {
        guard let data = defaults.data(forKey: key),
              let raw = try? JSONDecoder().decode([String: LossyCareer].self, from: data) else { return [:] }
        return raw.compactMapValues(\.career)
    }

    private struct LossyCareer: Decodable {
        let career: PresenterCareer?
        init(from decoder: Decoder) throws { career = try? PresenterCareer(from: decoder) }
    }
}
