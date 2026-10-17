import XCTest
@testable import AYSHostCore

final class PresenterLineBookTests: XCTestCase {
    func testEverySupportedLocaleHasACompleteOfflineBook() {
        XCTAssertEqual(Set(OfflinePresenterPack.supportedLocales), ["en", "it", "fr", "es", "pt", "de"])
        for locale in OfflinePresenterPack.supportedLocales {
            let book = PresenterLineBook.builtIn(locale: locale)
            XCTAssertEqual(book.locale, locale)
            XCTAssertFalse(book.variants(for: "result.everyoneWrong", intensity: .neutral).isEmpty)
            XCTAssertNotNil(book.render(template: "gameEnd.named", name: "SAM", intensity: .neutral, seed: 0))
            XCTAssertNotNil(book.render(template: "result.mixed.oneWrong.mechanic.button", name: "SAM", intensity: .savage, seed: 0))
            XCTAssertNotNil(book.render(template: "result.player.lss.lastLife", name: "SAM", intensity: .savage, seed: 0))
            XCTAssertEqual(book.templateVariants(for: "result.player.again", intensity: .savage).count, 3)
            XCTAssertTrue(book.templateVariants(for: "result.player.again", intensity: .neutral).isEmpty)
            XCTAssertEqual(book.sanitized(), book)
            XCTAssertNotNil(book.render(template: "result.title.king.named", name: "SAM", title: book.title(.king), intensity: .neutral, seed: 0))
            XCTAssertFalse(book.title(.king).isEmpty)
        }
    }

    func testUnsupportedOfflineLocaleFallsBackToEnglish() {
        XCTAssertEqual(PresenterLineBook.builtIn(locale: "ja").locale, "en")
    }

    private let sha = String(repeating: "ab", count: 32)

    /// The exact shape `npm run ays:pack` publishes (extra keys included).
    private func manifest(_ lines: String, templates: String = "{}", titles: String = "{}", format: Int = 1) -> Data {
        Data("""
        {"format":\(format),"locale":"it","revision":7,"publishedAt":"2026-10-06T10:00:00Z",
         "voice":{"pack":"el-v-eleven_v3","live":"el-v-eleven_flash_v2_5"},
         "lines":\(lines),"templates":\(templates),"titles":\(titles)}
        """.utf8)
    }

    func testDecodesPublishedManifestWithClips() throws {
        let data = manifest(#"{"lobby.empty":[{"id":"lobby.empty.a","text":"NESSUNO.","intensity":"any","clip":{"sha256":"\#(sha)","bytes":10,"identity":"x"}}]}"#)
        let book = try XCTUnwrap(PresenterLineBook.decode(data))
        XCTAssertEqual(book.revision, 7)
        XCTAssertEqual(book.voice?.live, "el-v-eleven_flash_v2_5")
        XCTAssertEqual(book.clipHashes, [sha])
    }

    func testRejectsNewerFormat() {
        XCTAssertNil(PresenterLineBook.decode(manifest("{}", format: 2)))
    }

    func testDropsInvalidCopyAndUnknownTemplates() throws {
        let data = manifest(
            #"{"a":[{"id":"a.1","text":"minuscolo","intensity":"any"}],"b":[{"id":"b.1","text":"OK.","intensity":"any","clip":{"sha256":"bad","bytes":1}}],"c":[{"id":"c.1","text":"OK.","intensity":"any"}]}"#,
            templates: #"{"title.named":[{"id":"t.1","text":"DA ORA SEI {title}.","intensity":"any"}],"mystery":[{"id":"m","text":"{name}","intensity":"any"}],"gameEnd.named":[{"id":"g","text":"{name} VINCE.","intensity":"any"}]}"#,
            titles: #"{"king":"IL RE","unknown":"X"}"#
        )
        let book = try XCTUnwrap(PresenterLineBook.decode(data))
        XCTAssertEqual(Set(book.lines.keys), ["c"])
        XCTAssertEqual(Set(book.templates.keys), ["gameEnd.named"])
        XCTAssertEqual(book.title(.king), "IL RE")
        XCTAssertEqual(book.title(.doesNotRead), "QUELLO CHE NON LEGGE")
    }

    func testAcceptsOnlyShippedResultFactTemplates() throws {
        let book = try XCTUnwrap(PresenterLineBook.decode(manifest(
            "{}",
            templates: #"{"result.mixed.oneWrong.mechanic.math":[{"id":"ok","text":"{name}, ERANO NUMERI PICCOLI.","intensity":"savage"}],"result.madeUpFact":[{"id":"bad","text":"{name} HA BARATO.","intensity":"savage"}]}"#
        )))
        XCTAssertNotNil(book.templates["result.mixed.oneWrong.mechanic.math"])
        XCTAssertNil(book.templates["result.madeUpFact"])
    }

    func testIntensityFiltersVariants() {
        let book = PresenterLineBook(locale: "it", revision: 1, lines: [
            "k": [.init(id: "k.soft", text: "SOFT.", intensity: .neutral), .init(id: "k.hard", text: "HARD.", intensity: .savage)],
        ], templates: [:], titles: [:])
        XCTAssertEqual(book.variants(for: "k", intensity: .savage).map(\.id), ["k.hard"])
        XCTAssertEqual(book.variants(for: "k", intensity: .neutral).map(\.id), ["k.soft"])
    }

    func testServerCanCoverANarrowerCaseWithoutAppChanges() {
        var lines = PresenterLineBook.builtIn.lines
        lines["result.everyoneWrong.firstRound"] = [.init(id: "first", text: "INIZIO COL BOTTO.", clip: .init(sha256: sha, bytes: 3))]
        let engine = PresenterEngine(lineBook: PresenterLineBook(locale: "it", revision: 2, lines: lines, templates: PresenterLineBook.builtIn.templates, titles: [:]))
        let fact = { PresenterRoundFact(roundId: UUID().uuidString, correctPlayerIds: [], wrongPlayerIds: ["1"]) }
        let first = engine.roundResult(fact(), players: [])[0]
        XCTAssertEqual(first.text, "INIZIO COL BOTTO.")
        XCTAssertEqual(first.clip?.sha256, sha)
        XCTAssertNotEqual(engine.roundResult(fact(), players: [])[0].text, "INIZIO COL BOTTO.")
    }

    func testRoundKeysGoFromSpecificToGeneric() {
        let engine = PresenterEngine()
        let wrong = { PresenterRoundFact(roundId: UUID().uuidString, correctPlayerIds: [], wrongPlayerIds: ["1", "2"]) }
        XCTAssertEqual(engine.roundResultKeys(wrong()), ["result.everyoneWrong.firstRound", "result.everyoneWrong"])
        _ = engine.roundResultKeys(wrong())
        XCTAssertEqual(engine.roundResultKeys(wrong()), ["result.everyoneWrong.streak3", "result.everyoneWrong"])
        let mixed = PresenterRoundFact(roundId: "m", correctPlayerIds: ["1", "2"], wrongPlayerIds: ["3"])
        XCTAssertEqual(engine.roundResultKeys(mixed), ["result.mixed.oneWrong", "result.mixed"])
        engine.beginMatch()
        XCTAssertEqual(engine.roundResultKeys(mixed), ["result.mixed.oneWrong", "result.mixed.firstRound", "result.mixed"])
    }

    func testRemoteTemplatesAndTitlesDriveNamedCues() {
        let book = PresenterLineBook(locale: "it", revision: 3, lines: PresenterLineBook.builtIn.lines, templates: [
            "gameEnd.named": [.init(id: "g", text: "{name} HA VINTO. INCREDIBILE.")],
        ], titles: ["kingUndisputed": "IL SOVRANO"])
        let engine = PresenterEngine(lineBook: book)
        let winner = PresenterPlayer(id: "1", displayName: "Luca", spokenName: "Luca")
        XCTAssertEqual(engine.gameEnd(winner: winner)?.text, "LUCA HA VINTO. INCREDIBILE.")
        engine.crownWinner("1")
        XCTAssertEqual(engine.currentTitle(for: "1"), .kingUndisputed)
        // A template missing from the book falls back to the in-code copy.
        XCTAssertEqual(engine.returningCue(player: winner, title: .kingUndisputed)?.text, "È TORNATO LUCA, IL SOVRANO.")
    }

    func testBuiltInBookIsValidAfterSanitizing() {
        let book = PresenterLineBook.builtIn
        XCTAssertEqual(book.sanitized(), book)
    }
}
