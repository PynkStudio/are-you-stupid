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
        PresenterCareerStore(defaults: defaults).remember(personaId: "p1", title: .king, now: now)
        XCTAssertEqual(PresenterCareerStore(defaults: defaults).career(for: "p1", now: now)?.title, .king)
    }

    func testNegativeTitlesExpireBeforePositiveTitles() {
        let now = Date()
        let store = PresenterCareerStore(defaults: defaults)
        store.remember(personaId: "bad", title: .doesNotRead, now: now.addingTimeInterval(-8 * 86_400))
        store.remember(personaId: "king", title: .king, now: now.addingTimeInterval(-8 * 86_400))
        XCTAssertNil(store.career(for: "bad", now: now))
        XCTAssertEqual(store.career(for: "king", now: now)?.title, .king)
    }

    func testATitleEarnedInEnglishIsSpokenInTheBoardsCurrentLocale() throws {
        let now = Date()
        let store = PresenterCareerStore(defaults: defaults)
        let english = PresenterEngine(lineBook: .builtIn(locale: "en"))
        english.crownWinner("1")
        store.remember(personaId: "p1", title: try XCTUnwrap(english.currentTitle(for: "1")), now: now)

        let italian = PresenterEngine(lineBook: .builtIn(locale: "it"))
        let luca = PresenterPlayer(id: "1", displayName: "Luca", spokenName: "Luca")
        let career = try XCTUnwrap(store.career(for: "p1", now: now))
        XCTAssertEqual(italian.returningCue(player: luca, title: career.title)?.text, "È TORNATO LUCA, IL KING INDISCUSSO.")
    }

    func testLegacyTextCareersMigrateToKeysAndUnknownOnesAreDropped() throws {
        let now = Date()
        let legacy = """
        {"en":{"title":"THE UNDISPUTED KING","lastSeen":\(now.timeIntervalSinceReferenceDate)},
         "de":{"title":"DER, DER NICHT LIEST","lastSeen":\(now.timeIntervalSinceReferenceDate)},
         "??":{"title":"SOMETHING ELSE","lastSeen":\(now.timeIntervalSinceReferenceDate)}}
        """
        defaults.set(Data(legacy.utf8), forKey: "ays.presenter.careers.v1")
        let store = PresenterCareerStore(defaults: defaults)
        XCTAssertEqual(store.career(for: "en", now: now)?.title, .kingUndisputed)
        XCTAssertEqual(store.career(for: "de", now: now)?.title, .doesNotRead)
        XCTAssertNil(store.career(for: "??", now: now))
        // A negative title worded in English now expires after 7 days too.
        XCTAssertNil(store.career(for: "de", now: now.addingTimeInterval(8 * 86_400)))
    }
}
