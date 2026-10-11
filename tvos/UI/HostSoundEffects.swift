import AVFoundation
import Foundation

enum HostSoundEffect: String {
    case roundStart = "round_start"
    case elimination
    case winner
    case partyPack = "party_pack"
}

/// Plays the board's generated stingers at a headphone-safe fixed gain.
/// Presenter speech has a separate player and remains independently mutable.
@MainActor
final class HostSoundEffects: NSObject, AVAudioPlayerDelegate {
    static let volume: Float = 0.32
    private var players: [AVAudioPlayer] = []

    func play(_ effect: HostSoundEffect) {
        guard let url = Bundle.module.url(
            forResource: effect.rawValue,
            withExtension: "mp3"
        ), let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.volume = Self.volume
        player.delegate = self
        players.append(player)
        player.play()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        players.removeAll { $0 === player }
    }
}
