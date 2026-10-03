import AVFoundation
import AYSHostCore
import Foundation

@MainActor
final class PresenterAudioController: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private let session = URLSession(configuration: .ephemeral)

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func play(
        _ cue: PresenterCue,
        intensity: PresenterIntensity,
        stillRelevant: @escaping @MainActor () -> Bool,
        onPlayback: @escaping @MainActor () -> Void
    ) {
        Task {
            if let local = bundledURL(for: cue), stillRelevant() {
                playFile(local, onPlayback: onPlayback)
                return
            }
            if let cached = cachedURL(for: cue), FileManager.default.fileExists(atPath: cached.path), stillRelevant() {
                playFile(cached, onPlayback: onPlayback)
                return
            }
            if let data = await fetch(cue, intensity: intensity), stillRelevant() {
                if cue.cacheable, let url = cachedURL(for: cue) { try? data.write(to: url, options: .atomic) }
                playData(data, onPlayback: onPlayback)
                return
            }
            guard stillRelevant() else { return }
            let utterance = AVSpeechUtterance(string: cue.text)
            utterance.voice = AVSpeechSynthesisVoice(language: "it-IT")
            utterance.rate = 0.48
            onPlayback()
            synthesizer.speak(utterance)
        }
    }

    private func fetch(_ cue: PresenterCue, intensity: PresenterIntensity) async -> Data? {
        guard
            let rawURL = Bundle.main.object(forInfoDictionaryKey: "AYSPresenterBackendURL") as? String,
            let url = URL(string: rawURL),
            let token = Bundle.main.object(forInfoDictionaryKey: "AYSPresenterAPIToken") as? String,
            !token.isEmpty
        else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 1.4)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "cueId": cue.id,
            "text": cue.text,
            "locale": "it",
            "intensity": intensity.rawValue,
            "cacheable": cue.cacheable,
        ])
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    private func bundledURL(for cue: PresenterCue) -> URL? {
        Bundle.main.url(forResource: cue.id.replacingOccurrences(of: ".", with: "_"), withExtension: "mp3", subdirectory: "PresenterPack")
    }

    private func cachedURL(for cue: PresenterCue) -> URL? {
        guard let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let folder = root.appendingPathComponent("Presenter/v\(OfflinePresenterPack.version)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let safe = cue.id.replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
        return folder.appendingPathComponent("\(safe).mp3")
    }

    private func playFile(_ url: URL, onPlayback: @escaping @MainActor () -> Void) {
        guard let data = try? Data(contentsOf: url) else { return }
        playData(data, onPlayback: onPlayback)
    }

    private func playData(_ data: Data, onPlayback: @escaping @MainActor () -> Void) {
        guard let audio = try? AVAudioPlayer(data: data) else { return }
        player = audio
        audio.delegate = self
        onPlayback()
        audio.play()
    }
}
