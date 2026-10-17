import AVFoundation
import AYSHostCore
import CryptoKit
import Foundation

/// Plays presenter cues through the cache-first voice ladder in
/// [[Multiplayer Presenter]]: pack clip (bundled or synced) → host disk
/// cache → backend speech → subtitle only. System speech is a DEBUG-only
/// safety net: in release a second, robotic voice is worse than silence.
/// The backend request waits as long as the cue stays relevant (not a fixed
/// timeout); a line still loading when its screen expires is dropped. Once
/// speech has actually started it is deliberately allowed to finish across
/// the next round. `prefetch` warms the disk cache for named lines the
/// engine may need at the next result.
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
    private var prefetchTask: Task<Void, Never>?

    /// Upper bound for one backend request; relevance usually ends it sooner.
    private static let liveRequestTimeout: TimeInterval = 8
    /// Prefetches per round, under the backend's 30 speech calls per minute
    /// per board so live requests keep headroom.
    static let prefetchBudgetPerRound = 8

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
        if let data = await fetchWhileRelevant(cue, intensity: intensity, stillRelevant: pending.stillRelevant) {
            if cue.cacheable, let cached { try? data.write(to: cached, options: .atomic) }
            if pending.stillRelevant(), playData(data, onPlayback: pending.onPlayback) { return }
        }
        guard pending.stillRelevant() else { finishCurrent(); return }
        #if DEBUG
        let utterance = AVSpeechUtterance(string: cue.text)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.speechLanguage(for: packs.locale))
        utterance.rate = 0.48
        pending.onPlayback()
        synthesizer.speak(utterance)
        #else
        pending.onPlayback()
        finishCurrent()
        #endif
    }

    /// Warms the disk cache for [texts] (most likely first) so a named line
    /// already has the host's voice when its result lands. Replaces the
    /// previous round's batch; skips lines already on disk. Cacheable only:
    /// these are templated lines with a validated spoken name.
    func prefetch(_ texts: [String], intensity: PresenterIntensity) {
        prefetchTask?.cancel()
        let missing = texts.filter { text in
            guard let url = liveCacheURL(text: text, intensity: intensity) else { return false }
            return !FileManager.default.fileExists(atPath: url.path)
        }
        guard !missing.isEmpty else { return }
        prefetchTask = Task { [weak self] in
            for text in missing.prefix(Self.prefetchBudgetPerRound) {
                guard let self, !Task.isCancelled else { return }
                guard let data = await self.fetch(cueId: "prefetch", text: text, intensity: intensity, cacheable: true),
                      let url = self.liveCacheURL(text: text, intensity: intensity) else { continue }
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    /// The backend request, abandoned as soon as the cue stops being
    /// relevant. The backend still finishes and caches it server-side, so the
    /// next use is a fast hit.
    private func fetchWhileRelevant(
        _ cue: PresenterCue,
        intensity: PresenterIntensity,
        stillRelevant: @escaping @MainActor () -> Bool
    ) async -> Data? {
        let request = Task { await fetch(cueId: cue.id, text: cue.text, intensity: intensity, cacheable: cue.cacheable) }
        let watchdog = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if !stillRelevant() { request.cancel(); return }
            }
        }
        let data = await request.value
        watchdog.cancel()
        return data
    }

    private func fetch(cueId: String, text: String, intensity: PresenterIntensity, cacheable: Bool) async -> Data? {
        guard let backend = PresenterBackend.configured else { return nil }
        var request = backend.request("api/ays/presenter", timeout: Self.liveRequestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "cueId": cueId,
            "text": text,
            "locale": packs.locale,
            "intensity": intensity.rawValue,
            "cacheable": cacheable,
        ])
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    private func liveCacheURL(for cue: PresenterCue, intensity: PresenterIntensity) -> URL? {
        liveCacheURL(text: cue.text, intensity: intensity)
    }

    /// Generated lines are cached by spoken text, delivery and the backend's
    /// live voice, so `LUCA HA VINTO` is fetched once per voice, not per cue.
    private func liveCacheURL(text: String, intensity: PresenterIntensity) -> URL? {
        guard let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let voice = (packs.book.voice?.live ?? "default").replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
        let folder = root.appendingPathComponent("Presenter/live/\(voice)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let key = SHA256.hash(data: Data("\(packs.locale)|\(intensity.rawValue)|\(text)".utf8))
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
