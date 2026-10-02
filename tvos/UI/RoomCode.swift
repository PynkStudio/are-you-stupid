//
//  RoomCode.swift
//  AYSHost
//
//  Random 4-character room codes — the join deep link and Bonjour instance
//  name contract (`_deepLinkRoomCode` in mp_home_screen.dart) only requires
//  `[A-Za-z0-9]{4}`, but visually ambiguous characters (0/O, 1/I/L) are
//  excluded here since a human sometimes has to read this off the TV and
//  type it as the `ENTER ROOM CODE` fallback ([[Multiplayer Product]]).
//

import Foundation

enum RoomCode {
    private static let alphabet = Array("23456789ABCDEFGHJKMNPQRSTUVWXYZ")

    static func random() -> String {
        String((0..<4).map { _ in alphabet.randomElement()! })
    }
}
