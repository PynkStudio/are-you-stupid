import Foundation

public struct PresenterCareer: Codable, Equatable, Sendable {
    public let title: String
    public let lastSeen: Date
}

public final class PresenterCareerStore {
    private let defaults: UserDefaults
    private let key = "ays.presenter.careers.v1"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func career(for personaId: String, now: Date = Date()) -> PresenterCareer? {
        guard let career = all()[personaId] else { return nil }
        let negative = career.title.contains("NON LEGGE") || career.title.contains("SCARSO") || career.title.contains("PEGGIORE")
        let lifetime: TimeInterval = negative ? 7 * 86_400 : 90 * 86_400
        return now.timeIntervalSince(career.lastSeen) <= lifetime ? career : nil
    }

    public func remember(personaId: String, title: String, now: Date = Date()) {
        var careers = all()
        careers[personaId] = PresenterCareer(title: title, lastSeen: now)
        if careers.count > 64 {
            for entry in careers.sorted(by: { $0.value.lastSeen < $1.value.lastSeen }).prefix(careers.count - 64) {
                careers.removeValue(forKey: entry.key)
            }
        }
        if let data = try? JSONEncoder().encode(careers) { defaults.set(data, forKey: key) }
    }

    private func all() -> [String: PresenterCareer] {
        guard let data = defaults.data(forKey: key),
              let careers = try? JSONDecoder().decode([String: PresenterCareer].self, from: data) else { return [:] }
        return careers
    }
}
