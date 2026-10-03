import XCTest
@testable import AYSHostCore

final class PresenterCareerStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: "PresenterCareerStoreTests")!
        defaults.removePersistentDomain(forName: "PresenterCareerStoreTests")
    }

    func testRemembersATitleAcrossStoreInstances() {
        let now = Date()
        PresenterCareerStore(defaults: defaults).remember(personaId: "p1", title: "IL KING", now: now)
        XCTAssertEqual(PresenterCareerStore(defaults: defaults).career(for: "p1", now: now)?.title, "IL KING")
    }

    func testNegativeTitlesExpireBeforePositiveTitles() {
        let now = Date()
        let store = PresenterCareerStore(defaults: defaults)
        store.remember(personaId: "bad", title: "QUELLO CHE NON LEGGE", now: now.addingTimeInterval(-8 * 86_400))
        store.remember(personaId: "king", title: "IL KING", now: now.addingTimeInterval(-8 * 86_400))
        XCTAssertNil(store.career(for: "bad", now: now))
        XCTAssertEqual(store.career(for: "king", now: now)?.title, "IL KING")
    }
}
