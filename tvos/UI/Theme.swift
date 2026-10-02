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
    static let accent = Color(red: 1.0, green: 0.85, blue: 0.1) // legacy stupid-yellow
    static let sunshine = Color(red: 1.0, green: 0.84, blue: 0.16)
    static let hotPink = Color(red: 1.0, green: 0.25, blue: 0.55)
    static let cyan = Color(red: 0.18, green: 0.88, blue: 0.96)
    static let ink = Color(red: 0.06, green: 0.035, blue: 0.13)
    static let stageTop = Color(red: 0.15, green: 0.04, blue: 0.31)
    static let stageBottom = Color(red: 0.025, green: 0.02, blue: 0.13)
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

/// Shared generated stage for the in-game board. Its energy stays at the
/// edges so the status or verdict in the middle remains readable at TV range.
struct GameStageBackground: View {
    var accent: Color = Theme.hotPink
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                    Gradient(colors: [Theme.stageTop, Theme.stageBottom]),
                    startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))

                for index in 0..<6 {
                    let phase = time * 0.08 + Double(index) * 1.13
                    let atLeft = index.isMultiple(of: 2)
                    let x = atLeft ? size.width * 0.02 : size.width * 0.98
                    let y = (sin(phase) * 0.38 + 0.5) * size.height
                    let diameter = CGFloat(180 + index * 24)
                    context.opacity = 0.055
                    context.fill(Path(ellipseIn: CGRect(
                        x: x - diameter / 2, y: y - diameter / 2,
                        width: diameter, height: diameter)), with: .color(accent))
                }
            }
        }
        .overlay {
            Rectangle().strokeBorder(Color.white.opacity(0.07), lineWidth: 2).padding(18)
        }
        .ignoresSafeArea()
    }
}

struct LiveBug: View {
    let text: String
    var color: Color = Theme.hotPink

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text.uppercased()).font(Theme.label(12))
        }
        .foregroundStyle(Color.white.opacity(0.7))
        .padding(.horizontal, 13).padding(.vertical, 8)
        .background(.black.opacity(0.3), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.1)))
    }
}
