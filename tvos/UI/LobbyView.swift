import AYSHostCore
import AYSProtocol
import SwiftUI

struct LobbyView: View {
    @ObservedObject var model: HostViewModel
    @State private var showingOptions = false

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 1050
            ZStack {
                PartyStageBackground()
                VStack(spacing: compact ? 14 : 22) {
                    LobbyMarquee(playerCount: model.roster.count)
                    HStack(alignment: .top, spacing: compact ? 18 : 30) {
                        JoinTicket(model: model, compact: compact)
                            .frame(width: min(geometry.size.width * 0.34, 430))
                        PartyRoster(model: model, compact: compact)
                    }
                    .frame(maxHeight: .infinity)
                }
                .padding(.horizontal, compact ? 24 : 48)
                .padding(.vertical, compact ? 20 : 32)
                if model.partyPackActive {
                    VStack {
                        HStack(spacing: 14) {
                            Text("✦").font(.system(size: 30, weight: .black))
                            VStack(spacing: 2) {
                                Text("PARTY PACK ACTIVATED").font(Theme.title(24))
                                Text("ONE PLAYER UNLOCKED 16 FOR EVERYONE.")
                                    .font(Theme.label(12))
                            }
                            Text("✦").font(.system(size: 30, weight: .black))
                        }
                        .padding(.horizontal, 28).padding(.vertical, 14)
                        .background(Theme.sunshine, in: Capsule())
                        .foregroundStyle(Theme.ink)
                        .shadow(color: Theme.sunshine.opacity(0.8), radius: 32)
                        Spacer()
                    }
                    .padding(.top, compact ? 74 : 92)
                    .transition(.scale(scale: 1.8).combined(with: .opacity))
                    .animation(.spring(response: 0.48, dampingFraction: 0.55), value: model.partyPackActive)
                }
            }
            .sheet(isPresented: $showingOptions) {
                PresenterOptionsView(model: model)
            }
            .overlay(alignment: .bottomLeading) {
                Button("OPTIONS") { showingOptions = true }
                    .font(Theme.label(12))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.black.opacity(0.32), in: Capsule())
                    .foregroundStyle(Color.white.opacity(0.68))
                    .padding(compact ? 18 : 28)
                    #if os(tvOS)
                    .buttonStyle(.card)
                    #else
                    .buttonStyle(.plain)
                    #endif
            }
        }
    }
}

private struct LobbyMarquee: View {
    let playerCount: Int

    private var subtitle: String {
        switch playerCount {
        case 0: return "GRAB YOUR PHONES. BAD DECISIONS START HERE."
        case 1: return "ONE LEGEND IN. WHO'S BRAVE ENOUGH TO JOIN?"
        default: return "\(playerCount) PLAYERS. ZERO EXCUSES."
        }
    }

    var body: some View {
        HStack(spacing: 18) {
            Text("● LIVE").font(Theme.label(16)).foregroundStyle(Theme.hotPink)
            // The brand never wraps; the divider and subtitle give way instead.
            ShoutText(text: "ARE YOU STUPID?!", size: 34).fixedSize()
            Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)
            Text(subtitle)
                .font(Theme.label(15)).foregroundStyle(Color.white.opacity(0.72)).lineLimit(1)
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
        .background(.black.opacity(0.25), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}

private struct JoinTicket: View {
    @ObservedObject var model: HostViewModel
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 12 : 18) {
            VStack(spacing: 2) {
                Text("YOUR PHONE IS THE CONTROLLER")
                    .font(Theme.label(compact ? 12 : 14)).foregroundStyle(Theme.sunshine)
                ShoutText(text: "SCAN. JOIN. PANIC.", size: compact ? 24 : 30)
            }
            model.joinQRImage
                .interpolation(.none).resizable()
                .frame(width: compact ? 158 : 200, height: compact ? 158 : 200)
                .padding(10).background(Color.white, in: RoundedRectangle(cornerRadius: 18))
                .shadow(color: Theme.cyan.opacity(0.45), radius: 22)
            VStack(spacing: 3) {
                Text("OR ENTER ROOM CODE").font(Theme.label(12)).foregroundStyle(Color.white.opacity(0.55))
                Text(model.roomCode)
                    .font(.system(size: compact ? 42 : 54, weight: .black, design: .monospaced))
                    .tracking(8).foregroundStyle(Theme.sunshine)
            }
            HStack(spacing: 8) {
                Circle().fill(Theme.correct).frame(width: 8, height: 8)
                Text(model.networkStatus.uppercased())
                    .font(Theme.label(11)).lineLimit(1).foregroundStyle(Color.white.opacity(0.65))
            }
            #if os(macOS)
            AirPlayButton().frame(width: 30, height: 30)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(compact ? 18 : 26)
        .background(.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Theme.cyan.opacity(0.32), lineWidth: 2))
    }
}

private struct PartyRoster: View {
    @ObservedObject var model: HostViewModel
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 18) {
            HStack(alignment: .firstTextBaseline) {
                ShoutText(text: "WHO'S IN?", size: compact ? 28 : 38)
                Spacer()
                Text("\(model.roster.count)/\(model.maxPlayers) PLAYERS").font(Theme.label(14)).foregroundStyle(Theme.cyan)
            }
            Group {
                if model.roster.isEmpty {
                    EmptyDanceFloor()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: compact ? 10 : 14) {
                            ForEach(Array(model.roster.enumerated()), id: \.element.playerId) { index, player in
                                PlayerCard(player: player, seat: index + 1)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            ModePicker(model: model)
            StartPanel(model: model)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PresenterOptionsView: View {
    @ObservedObject var model: HostViewModel
    private let labels = ["en": "EN", "it": "IT", "fr": "FR", "es": "ES", "pt": "PT", "de": "DE"]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 28) {
                ShoutText(text: "OPTIONS", size: 38, color: Theme.sunshine)
                VStack(alignment: .leading, spacing: 12) {
                    Text("PRESENTER LANGUAGE").font(Theme.label(12)).foregroundStyle(Theme.cyan)
                    HStack(spacing: 10) {
                        ForEach(model.presenterLocales, id: \.self) { locale in
                            option(labels[locale] ?? locale.uppercased(), selected: model.presenterLocale == locale) {
                                model.selectPresenterLocale(locale)
                            }
                        }
                    }
                    Text("DEFAULTS TO THIS DEVICE'S LANGUAGE. UNSUPPORTED LANGUAGES USE ENGLISH.")
                        .font(Theme.label(10)).foregroundStyle(Color.white.opacity(0.42))
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("PRESENTER OUTPUT").font(Theme.label(12)).foregroundStyle(Theme.cyan)
                    HStack(spacing: 10) {
                        ForEach(PresenterOutputMode.allCases, id: \.rawValue) { mode in
                            option(mode.rawValue.uppercased(), selected: model.presenterOutputMode == mode) {
                                model.selectPresenterOutputMode(mode)
                            }
                        }
                    }
                    Text("OFF HIDES EVERYTHING. MUTE SHOWS CAPTIONS WITHOUT VOICE.")
                        .font(Theme.label(10)).foregroundStyle(Color.white.opacity(0.42))
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("ROAST LEVEL").font(Theme.label(12)).foregroundStyle(Theme.cyan)
                    HStack(spacing: 10) {
                        ForEach(PresenterIntensity.allCases, id: \.rawValue) { intensity in
                            option(intensity.rawValue.uppercased(), selected: model.presenterIntensity == intensity) {
                                model.selectPresenterIntensity(intensity)
                            }
                            .disabled(model.presenterOutputMode == .off)
                            .opacity(model.presenterOutputMode == .off ? 0.38 : 1)
                        }
                    }
                }
                Spacer()
            }
            .padding(46).frame(maxWidth: 760, maxHeight: 640, alignment: .leading)
        }
    }

    private func option(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .font(Theme.label(13)).padding(.horizontal, 18).padding(.vertical, 12)
            .background(selected ? Theme.sunshine : Color.white.opacity(0.09))
            .foregroundStyle(selected ? Theme.ink : .white)
            .clipShape(Capsule())
            #if os(tvOS)
            .buttonStyle(.card)
            #else
            .buttonStyle(.plain)
            #endif
    }
}

private struct EmptyDanceFloor: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bouncing = false

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ForEach(["🪩", "🤡", "🧠"], id: \.self) { emoji in
                    Text(emoji).font(.system(size: 42)).offset(y: bouncing && !reduceMotion ? -8 : 5)
                }
            }
            ShoutText(text: "THE DANCE FLOOR IS EMPTY", size: 22, color: Theme.sunshine)
            Text("SCAN THE CODE. BE THE FIRST BAD INFLUENCE.")
                .font(Theme.label(14)).foregroundStyle(Color.white.opacity(0.58))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cardBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24)
            .stroke(style: StrokeStyle(lineWidth: 2, dash: [9, 8])).foregroundStyle(Color.white.opacity(0.16)))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { bouncing = true }
        }
    }
}

private struct PlayerCard: View {
    let player: PlayerInfo
    let seat: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(player.ready ? Theme.correct : Theme.hotPink)
                Text(player.emoji.isEmpty ? "🙂" : player.emoji).font(.system(size: 28))
            }.frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text("PLAYER \(seat)").font(Theme.label(10)).foregroundStyle(Color.white.opacity(0.45))
                Text(player.playerName.uppercased()).font(Theme.label(19)).lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(player.ready ? "READY!" : "WARMING UP")
                .font(Theme.label(11)).foregroundStyle(player.ready ? Theme.correct : Color.white.opacity(0.45))
        }
        .padding(13).background(Theme.cardBackground.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .stroke(player.ready ? Theme.correct.opacity(0.75) : Color.white.opacity(0.09), lineWidth: 2))
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}

private struct StartPanel: View {
    @ObservedObject var model: HostViewModel

    private var status: String {
        if model.readyCount == 0 { return "WAITING FOR 2 READY PLAYERS" }
        if model.readyCount == 1 { return "ONE MORE READY PLAYER" }
        return "THE PARTY IS READY"
    }

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 7) {
                ForEach(0..<2, id: \.self) { index in
                    Capsule().fill(index < model.readyCount ? Theme.correct : Color.white.opacity(0.16)).frame(height: 6)
                }
            }
            Button(action: { model.startGame() }) {
                HStack {
                    Text(model.canStart ? "START THE CHAOS" : status)
                    Spacer()
                    Text(model.canStart ? "→" : "\(model.readyCount)/2")
                }
                .font(Theme.title(20)).padding(.horizontal, 22).padding(.vertical, 16).frame(maxWidth: .infinity)
            }
            .disabled(!model.canStart)
            .background(model.canStart ? Theme.sunshine : Color.white.opacity(0.09))
            .foregroundStyle(model.canStart ? Theme.ink : Color.white.opacity(0.42))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            #if os(tvOS)
            .buttonStyle(.card)
            #else
            .buttonStyle(.plain)
            #endif
        }
    }
}

private struct ModePicker: View {
    @ObservedObject var model: HostViewModel

    var body: some View {
        HStack(spacing: 10) {
            option("STUPID BATTLE", detail: "20 ROUNDS", mode: .stupidBattle)
            option("LAST STUPID STANDING", detail: "3 LIVES", mode: .lastStupidStanding)
        }
    }

    private func option(_ title: String, detail: String, mode: GameMode) -> some View {
        let selected = model.selectedMode == mode
        return Button(action: { model.selectedMode = mode }) {
            VStack(spacing: 2) {
                Text(title).font(Theme.label(13)).lineLimit(1)
                Text(detail).font(Theme.label(9)).opacity(0.65)
            }.frame(maxWidth: .infinity).padding(.vertical, 11)
        }
        .background(selected ? Theme.cyan : Theme.cardBackground.opacity(0.8))
        .foregroundStyle(selected ? Theme.ink : .white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(selected ? 0 : 0.1)))
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
    }
}

private struct PartyStageBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                    Gradient(colors: [Theme.stageTop, Theme.stageBottom]), startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)))
                let colors = [Theme.hotPink, Theme.cyan, Theme.sunshine]
                for index in 0..<12 {
                    let phase = time * (0.035 + Double(index % 3) * 0.008) + Double(index) * 0.47
                    let x = (sin(phase) * 0.42 + 0.5) * size.width
                    let y = (cos(phase * 1.31) * 0.42 + 0.5) * size.height
                    let diameter = CGFloat(80 + (index % 4) * 34)
                    let rect = CGRect(x: x - diameter / 2, y: y - diameter / 2, width: diameter, height: diameter)
                    context.opacity = 0.08
                    context.fill(Path(ellipseIn: rect), with: .color(colors[index % colors.count]))
                }
            }
        }
        .overlay { LinearGradient(colors: [.clear, .black.opacity(0.28)], startPoint: .top, endPoint: .bottom) }
        .ignoresSafeArea()
    }
}
