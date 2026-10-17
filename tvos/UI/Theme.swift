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

/// Every in-game board is composed on a 1280×720 design canvas and scaled
/// by `unit`, so the same hierarchy holds on a 1920×1080 Apple TV and on a
/// small resizable Mac window instead of drifting with fixed point sizes.
struct BoardCanvas<Content: View>: View {
    @ViewBuilder let content: (CGFloat) -> Content

    var body: some View {
        GeometryReader { geometry in
            let unit = max(0.5, min(geometry.size.width / 1280, geometry.size.height / 720))
            content(unit).frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

/// Broadcast chrome: where we are in the match on the left, the brand on the
/// right, a hairline below. Plain type — no badges, no capsules.
struct BoardHeader: View {
    let title: String
    var detail: String? = nil
    let unit: CGFloat

    var body: some View {
        VStack(spacing: 12 * unit) {
            HStack(alignment: .firstTextBaseline, spacing: 14 * unit) {
                Text(title).font(Theme.title(22 * unit)).foregroundStyle(.white)
                if let detail {
                    Text(detail).font(Theme.label(14 * unit)).tracking(1.5 * unit)
                        .foregroundStyle(Color.white.opacity(0.45))
                }
                Spacer(minLength: 12 * unit)
                Text("ARE YOU STUPID?!").font(Theme.title(15 * unit)).fixedSize()
                    .foregroundStyle(Color.white.opacity(0.38))
            }
            Rectangle().fill(Color.white.opacity(0.1)).frame(height: max(1, unit))
        }
    }
}

/// The presenter's line, styled like a broadcast subtitle: the exact spoken
/// text, readable from the sofa, anchored by a single accent rule.
struct PresenterCaption: View {
    let text: String
    let unit: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 16 * unit) {
            Rectangle().fill(Theme.cyan).frame(width: 4 * unit)
            Text("“\(text.uppercased())”")
                .font(Theme.title(21 * unit)).foregroundStyle(Color.white.opacity(0.92))
                .lineLimit(2).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Lives as hearts. In elimination mode the heart lost this round is the
/// story, so it flashes red before settling into an empty outline.
struct HeartsView: View {
    let remaining: Int
    var total: Int = 3
    var lostThisRound = false
    let size: CGFloat
    @State private var settled = false

    var body: some View {
        HStack(spacing: size * 0.22) {
            ForEach(0..<max(total, remaining), id: \.self) { index in
                let justLost = lostThisRound && index == remaining
                Image(systemName: index < remaining ? "heart.fill" : (justLost ? "heart.slash.fill" : "heart"))
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(index < remaining ? Theme.hotPink
                                     : justLost ? Theme.wrong.opacity(settled ? 0.55 : 1)
                                     : Color.white.opacity(0.18))
                    .scaleEffect(justLost && !settled ? 1.35 : 1)
            }
        }
        .onAppear {
            guard lostThisRound else { return }
            withAnimation(.easeOut(duration: 0.6).delay(0.35)) { settled = true }
        }
    }
}

/// The "no downtime" auto-advance made visible: a hairline that fills while
/// the board holds on the reveal, so nobody wonders whether it froze.
struct AdvanceBar: View {
    let label: String
    let duration: Double
    let unit: CGFloat
    @State private var progress: CGFloat = 0

    var body: some View {
        HStack(spacing: 14 * unit) {
            Text(label).font(Theme.label(11 * unit)).tracking(2 * unit)
                .foregroundStyle(Color.white.opacity(0.4)).fixedSize()
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.08))
                    Rectangle().fill(Color.white.opacity(0.45)).frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: max(2, 3 * unit))
        }
        .onAppear { withAnimation(.linear(duration: duration)) { progress = 1 } }
    }
}

extension Int {
    /// `842` → `0.84S` — reaction times read as seconds on a TV.
    var asSeconds: String { String(format: "%.2fS", Double(self) / 1000) }
}

/// Reveal animations start hidden and run from `onAppear`. A still render
/// (the snapshot tests) has no appear pass, so it asks for the final frame
/// the same way Reduce Motion does.
private struct BoardStillKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var boardStill: Bool {
        get { self[BoardStillKey.self] }
        set { self[BoardStillKey.self] = newValue }
    }
}
