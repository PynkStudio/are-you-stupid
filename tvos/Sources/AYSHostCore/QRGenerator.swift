//
//  QRGenerator.swift
//  AYSHostCore
//
//  On-device QR generation for the join deep link — zero bundled assets,
//  per the game's "no external assets" pillar (docs/Gameplay/Game Design
//  Pillars.md) and docs/Architecture/Multiplayer Host (tvOS).md's "QR
//  generation (no assets)". `CIQRCodeGenerator` renders the deep link at its
//  native module resolution; scaling up is nearest-neighbor (no
//  interpolation) so the modules stay crisp instead of blurring into an
//  unscannable code.
//
//  CoreImage only — no SwiftUI/UIKit/AppKit — so this stays usable from
//  tvOS, iOS and macOS alike and is unit-testable via `swift test` without a
//  UI, same spirit as HostClock/HostTransport.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

public enum QRGenerator {
    /// Mirrors lib/ui/screens/multiplayer/mp_home_screen.dart's
    /// `_deepLinkRoomCode` contract exactly: `areyoustupid://join?room=XXXX`.
    public static func joinDeepLink(roomCode: String) -> String {
        "areyoustupid://join?room=\(roomCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())"
    }

    /// Renders `text` as a QR code and returns it as a `CGImage`, scaled up
    /// by `scale` (an integer pixel-per-module multiplier — keeps edges
    /// sharp; SwiftUI can scale further with `.interpolation(.none)`).
    /// Returns nil only if CoreImage itself fails to produce a code, which
    /// in practice means `text` is too long for a QR symbol.
    public static func cgImage(for text: String, scale: Int = 10) -> CGImage? {
        guard let data = text.data(using: .utf8) else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale))
        let scaledImage = outputImage.transformed(by: transform)

        let context = CIContext()
        return context.createCGImage(scaledImage, from: scaledImage.extent)
    }

    /// Convenience for the common case: the join deep link for `roomCode`,
    /// rendered straight to a `CGImage`.
    public static func joinCode(roomCode: String, scale: Int = 10) -> CGImage? {
        cgImage(for: joinDeepLink(roomCode: roomCode), scale: scale)
    }
}
