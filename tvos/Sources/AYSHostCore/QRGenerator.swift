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
    /// `_deepLinkRoomCode` contract: a universal link,
    /// `https://pynkstudio.eu/ays/join?room=XXXX`. An https URL — not the
    /// app's custom scheme — because players (and App Review) scan the TV
    /// with the system camera: with the app installed iOS opens it straight
    /// into the room (applinks:pynkstudio.eu), without it the page offers the
    /// App Store. A custom scheme there reads "No usable data found".
    ///
    /// `hostHint` (`"192.168.1.20:54321"`, the board's LAN address and bound
    /// port) is appended as `&h=` so a phone whose Bonjour lookup fails —
    /// networks that drop multicast — can still connect directly.
    public static func joinDeepLink(roomCode: String, hostHint: String? = nil) -> String {
        let room = roomCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let hostHint, !hostHint.isEmpty else {
            return "https://pynkstudio.eu/ays/join?room=\(room)"
        }
        return "https://pynkstudio.eu/ays/join?room=\(room)&h=\(hostHint)"
    }

    /// `"ip:port"` for the QR's direct-connect hint, or nil when either part
    /// is unknown.
    public static func hostHint(address: String?, port: UInt16?) -> String? {
        guard let address, !address.isEmpty, let port, port > 0 else { return nil }
        return "\(address):\(port)"
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
    public static func joinCode(roomCode: String, hostHint: String? = nil, scale: Int = 10) -> CGImage? {
        cgImage(for: joinDeepLink(roomCode: roomCode, hostHint: hostHint), scale: scale)
    }
}
