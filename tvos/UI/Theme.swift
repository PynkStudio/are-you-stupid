//
//  Theme.swift
//  AYSHost
//
//  Shared look for the tvOS + macOS board: dark ground, bold uppercase
//  system type, no bundled assets — the same "zero external assets" pillar
//  the Flutter app follows (docs/Gameplay/Game Design Pillars.md), and the
//  "game-show, not a mirrored phone" brief in docs/Gameplay/Multiplayer
//  Gameplay.md "TV presentation".
//

import SwiftUI

enum Theme {
    static let background = Color.black
    static let accent = Color(red: 1.0, green: 0.85, blue: 0.1) // stupid-yellow
    static let correct = Color(red: 0.25, green: 0.85, blue: 0.45)
    static let wrong = Color(red: 0.95, green: 0.3, blue: 0.3)
    static let cardBackground = Color(white: 0.12)

    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    static func label(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}

/// Uppercase, bold, high-contrast — mirrors the mobile app's ALL-CAPS
/// instruction style so the board and the phones feel like one game.
struct ShoutText: View {
    let text: String
    var size: CGFloat = 32
    var color: Color = .white

    var body: some View {
        Text(text.uppercased())
            .font(Theme.title(size))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
    }
}
