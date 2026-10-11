//
//  AYSHostApp.swift
//  AYSHost
//
//  tvOS entry point. The board itself lives in the AYSHostUI package
//  library, which the macOS Flutter app also embeds (MULTIPLAYER → HOST ON
//  THIS MAC opens it in its own window) — see docs/Architecture/Multiplayer
//  Host (tvOS).md.
//

import SwiftUI
import AYSHostUI

@main
struct AYSHostApp: App {
    var body: some Scene {
        WindowGroup {
            AYSHostBoardView()
        }
    }
}
