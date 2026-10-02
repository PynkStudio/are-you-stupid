//
//  AirPlayButton.swift
//  AYSHost
//
//  macOS-only: lets the board-only Mac host mirror to another screen via
//  AirPlay, per docs/Architecture/Multiplayer Host (tvOS).md "macOS board
//  host (no direct play) + AirPlay" — there is no equivalent on tvOS, where
//  the board *is* the primary output.
//

#if os(macOS)
import AVKit
import SwiftUI

struct AirPlayButton: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.isRoutePickerButtonBordered = false
        return view
    }

    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {}
}
#endif
