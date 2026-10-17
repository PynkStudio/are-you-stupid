import XCTest
@testable import AYSHostCore

final class BoardStringsTests: XCTestCase {
    func testEveryLocaleCoversEveryKey() {
        XCTAssertEqual(Set(BoardStrings.tables.keys), Set(OfflinePresenterPack.supportedLocales))
        for (locale, table) in BoardStrings.tables {
            let missing = BoardStrings.Key.allCases.filter { table[$0] == nil }
            XCTAssertTrue(missing.isEmpty, "\(locale) is missing \(missing.map(\.rawValue))")
        }
    }

    func testPlaceholdersMatchEnglish() {
        let pattern = try! NSRegularExpression(pattern: "\\{[a-z]+\\}")
        func slots(_ text: String) -> Set<String> {
            Set(pattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
                .map { String(text[Range($0.range, in: text)!]) })
        }
        for (locale, table) in BoardStrings.tables {
            for key in BoardStrings.Key.allCases {
                XCTAssertEqual(slots(table[key] ?? ""), slots(BoardStrings.en[key]!), "\(locale).\(key.rawValue)")
            }
        }
    }

    func testCopyIsUppercase() {
        for (locale, table) in BoardStrings.tables {
            for (key, text) in table {
                let withoutSlots = text.replacingOccurrences(of: "\\{[a-z]+\\}", with: "", options: .regularExpression)
                XCTAssertEqual(withoutSlots, withoutSlots.uppercased(), "\(locale).\(key.rawValue)")
            }
        }
    }

    func testItalianBoardAndFallbacks() {
        let it = BoardStrings(locale: "it")
        XCTAssertEqual(it(.roundTitle, ["n": 3]), "ROUND 3")
        XCTAssertEqual(it(.playerIsOut, ["name": "LUCA"]), "LUCA È FUORI.")
        XCTAssertEqual(it.failReason("too slow"), "TROPPO LENTO")
        XCTAssertEqual(it.failReason(""), "AVEVI UN SOLO COMPITO.")
        XCTAssertEqual(it.failReason("Tapped the decoy."), "TAPPED THE DECOY.")
        XCTAssertEqual(BoardStrings(locale: "ja").locale, "en")
    }
}
