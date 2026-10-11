import AVFoundation
import AYSHostCore
import CryptoKit
import Foundation

/// Plays presenter cues through the cache-first voice ladder in
/// [[Multiplayer Presenter]]: pack clip (bundled or synced) → host disk
/// cache → backend speech → system speech (development safety net).
/// Every step re-checks `stillRelevant` before playback, so a line still
/// loading when its screen expires is dropped. Once speech has actually
/// started it is deliberately allowed to finish across the next round.
@MainActor
final class PresenterAudioController: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    private struct PendingCue {
        let cue: PresenterCue
        let intensity: PresenterIntensity
        let stillRelevant: @MainActor () -> Bool
        let onPlayback: @MainActor () -> Void
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private let session = URLSession(configuration: .ephemeral)
    private let packs: PresenterPackStore
    private var queue: [PendingCue] = []
    private var isPlaying = false

    init(packs: PresenterPackStore) {
        self.packs = packs
        super.init()
        synthesizer.delegate = self
    }

    func play(
        _ cue: PresenterCue,
        intensity: PresenterIntensity,
        stillRelevant: @escaping @MainActor () -> Bool,
        onPlayback: @escaping @MainActor () -> Void
    ) {
        queue.append(PendingCue(cue: cue, intensity: intensity, stillRelevant: stillRelevant, onPlayback: onPlayback))
        startNextIfNeeded()
    }

    private func startNextIfNeeded() {
        guard !isPlaying else { return }
        while !queue.isEmpty {
            let pending = queue.removeFirst()
            guard pending.stillRelevant() else { continue }
            isPlaying = true
            Task { await resolve(pending) }
            return
        }
    }

    private func resolve(_ pending: PendingCue) async {
        let cue = pending.cue
        let intensity = pending.intensity
        if let clip = cue.clip, let local = packs.localURL(for: clip), pending.stillRelevant(),
           playFile(local, onPlayback: pending.onPlayback) {
            return
        }
        let cached = liveCacheURL(for: cue, intensity: intensity)
        if let cached, FileManager.default.fileExists(atPath: cached.path), pending.stillRelevant(),
           playFile(cached, onPlayback: pending.onPlayback) {
            return
        }
        if let data = await fetch(cue, intensity: intensity), pending.stillRelevant() {
            if cue.cacheable, let cached { try? data.write(to: cached, options: .atomic) }
            if playData(data, onPlayback: pending.onPlayback) { return }
        }
        guard pending.stillRelevant() else { finishCurrent(); return }
        let utterance = AVSpeechUtterance(string: cue.text)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.speechLanguage(for: packs.locale))
        utterance.rate = 0.48
        pending.onPlayback()
        synthesizer.speak(utterance)
    }

    private func fetch(_ cue: PresenterCue, intensity: PresenterIntensity) async -> Data? {
        guard let backend = PresenterBackend.configured else { return nil }
        var request = backend.request("api/ays/presenter", timeout: 1.4)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "cueId": cue.id,
            "text": cue.text,
            "locale": packs.locale,
            "intensity": intensity.rawValue,
            "cacheable": cue.cacheable,
        ])
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    /// Generated lines are cached by spoken text, delivery and the backend's
    /// live voice, so `LUCA HA VINTO` is fetched once per voice, not per cue.
    private func liveCacheURL(for cue: PresenterCue, intensity: PresenterIntensity) -> URL? {
        guard let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let voice = (packs.book.voice?.live ?? "default").replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
        let folder = root.appendingPathComponent("Presenter/live/\(voice)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let key = SHA256.hash(data: Data("\(packs.locale)|\(intensity.rawValue)|\(cue.text)".utf8))
            .map { String(format: "%02x", $0) }.joined()
        return folder.appendingPathComponent("\(key).mp3")
    }

    private static func speechLanguage(for locale: String) -> String {
        ["en": "en-US", "it": "it-IT", "fr": "fr-FR", "es": "es-ES", "pt": "pt-PT", "de": "de-DE"][locale] ?? "en-US"
    }

    private func playFile(_ url: URL, onPlayback: @escaping @MainActor () -> Void) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        return playData(data, onPlayback: onPlayback)
    }

    private func playData(_ data: Data, onPlayback: @escaping @MainActor () -> Void) -> Bool {
        guard let audio = try? AVAudioPlayer(data: data) else { return false }
        player = audio
        audio.delegate = self
        guard audio.play() else { player = nil; return false }
        onPlayback()
        return true
    }

    private func finishCurrent() {
        player = nil
        isPlaying = false
        startNextIfNeeded()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.finishCurrent() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.finishCurrent() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.finishCurrent() }
    }
}
