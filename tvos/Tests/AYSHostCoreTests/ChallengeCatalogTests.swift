//
//  ChallengeCatalogTests.swift
//  AYSHostCoreTests
//
//  Cheap invariants for AYSChallengeCatalog.all — mostly a tripwire against
//  a copy/paste slip in the id list or a maxDurationMs of 0 (which would
//  make RoomHost force-close a round instantly).
//

import XCTest
@testable import AYSHostCore

final class ChallengeCatalogTests: XCTestCase {
    func testHasAllThirtyNineTemplates() {
        XCTAssertEqual(AYSChallengeCatalog.all.count, 39)
    }

    func testIdsAreUnique() {
        let ids = AYSChallengeCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEveryEntryHasAPositiveDuration() {
        for entry in AYSChallengeCatalog.all {
            XCTAssertGreaterThan(
                entry.maxDurationMs, 0,
                "\(entry.id) has a non-positive maxDurationMs"
            )
        }
    }

    func testEveryEntryHasAPositiveWeightAndMinLevel() {
        for entry in AYSChallengeCatalog.all {
            XCTAssertGreaterThan(entry.weight, 0, "\(entry.id) has a non-positive weight")
            XCTAssertGreaterThanOrEqual(entry.minLevel, 1, "\(entry.id) has minLevel < 1")
        }
    }
}
