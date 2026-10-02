//
//  AYSHostApp.swift
//  AYSHost
//
//  Shared entry point for both the tvOS and macOS targets — one SwiftUI
//  `App`/`Scene` lifecycle, one `RootView`, per docs/Architecture/Multiplayer
//  Host (tvOS).md: "The protocol, authority rules, scoring and UI are shared
//  unchanged between the two targets."
//

import SwiftUI

@main
struct AYSHostApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                #if os(macOS)
                .frame(minWidth: 900, minHeight: 600)
                #endif
        }
    }
}
