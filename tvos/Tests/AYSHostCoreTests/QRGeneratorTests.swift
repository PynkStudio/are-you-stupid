//
//  QRGeneratorTests.swift
//  AYSHostCoreTests
//
//  No real QR decoder is linked into this package, so these don't prove
//  "a phone camera can scan this" — that's Phase 10's real-device pass
//  ([[Multiplayer Development]]). What's provable headless: the deep link
//  string matches the client's parsing contract, generation is
//  deterministic, different input produces different pixels, and scaling
//  behaves as documented.
//

import AYSHostCore
import XCTest

final class QRGeneratorTests: XCTestCase {
    func testJoinDeepLinkMatchesTheClientContract() {
        // Mirrors lib/ui/screens/multiplayer/mp_home_screen.dart's
        // `_deepLinkRoomCode` regex exactly.
        XCTAssertEqual(QRGenerator.joinDeepLink(roomCode: "7f4k"), "areyoustupid://join?room=7F4K")
        XCTAssertEqual(QRGenerator.joinDeepLink(roomCode: "  aB3d  "), "areyoustupid://join?room=AB3D")
    }

    func testProducesAnImageOfTheExpectedScaledSize() throws {
        let image = try XCTUnwrap(QRGenerator.cgImage(for: "areyoustupid://join?room=7F4K", scale: 10))
        // A version-1 QR symbol (this payload's length) is 21x21 modules
        // plus quiet zone per CIQRCodeGenerator's own margin; just assert
        // it's square and scales proportionally with `scale`, without
        // pinning an exact module count to CoreImage's internals.
        XCTAssertEqual(image.width, image.height)

        let doubled = try XCTUnwrap(QRGenerator.cgImage(for: "areyoustupid://join?room=7F4K", scale: 20))
        XCTAssertEqual(doubled.width, image.width * 2)
        XCTAssertEqual(doubled.height, image.height * 2)
    }

    func testIsDeterministicForTheSameInput() throws {
        let a = try XCTUnwrap(QRGenerator.cgImage(for: "areyoustupid://join?room=7F4K"))
        let b = try XCTUnwrap(QRGenerator.cgImage(for: "areyoustupid://join?room=7F4K"))
        XCTAssertEqual(a.width, b.width)
        XCTAssertEqual(try pixelData(a), try pixelData(b))
    }

    func testDifferentRoomCodesProduceDifferentPixels() throws {
        let a = try XCTUnwrap(QRGenerator.joinCode(roomCode: "7F4K"))
        let b = try XCTUnwrap(QRGenerator.joinCode(roomCode: "XY9Z"))
        XCTAssertNotEqual(try pixelData(a), try pixelData(b))
    }

    /// Renders a `CGImage` to raw RGBA bytes for a pixel-level comparison —
    /// `CGImage` itself isn't `Equatable`.
    private func pixelData(_ image: CGImage) throws -> Data {
        let width = image.width
        let height = image.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(CGContext(
            data: &buffer, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return Data(buffer)
    }
}
