import AYSHostCore
import CryptoKit
import Foundation

/// PynkStudio presenter backend, configured through Info.plist build
/// settings (`AYS_PRESENTER_BACKEND_URL`, `AYS_PRESENTER_API_TOKEN`). Absent
/// or unexpanded values mean "offline presenter": bundled clips, subtitles
/// and — in development — system speech.
struct PresenterBackend {
    let baseURL: URL
    let token: String

    static let configured: PresenterBackend? = {
        guard
            let rawURL = Bundle.main.object(forInfoDictionaryKey: "AYSPresenterBackendURL") as? String,
            let token = Bundle.main.object(forInfoDictionaryKey: "AYSPresenterAPIToken") as? String,
            !rawURL.contains("$("), !token.contains("$("), !token.isEmpty,
            let url = URL(string: rawURL.hasSuffix("/") ? String(rawURL.dropLast()) : rawURL),
            url.scheme == "https"
        else { return nil }
        return PresenterBackend(baseURL: url, token: token)
    }()

    func request(_ path: String, query: [URLQueryItem] = [], timeout: TimeInterval) -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!, timeoutInterval: timeout)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}

/// Owns the presenter line book the board speaks from and the clips behind
/// it. Resolution: the newer of (synced copy in Caches, pack bundled with
/// the app), else the in-code baseline. A sync downloads the published
/// manifest, fetches and hash-verifies every missing clip, and only then
/// swaps the manifest — a half-downloaded pack is never used. Clips the new
/// manifest no longer references are deleted, so an invalidated recording
/// disappears from the board on its next sync. See [[Multiplayer Presenter]].
@MainActor
final class PresenterPackStore {
    private(set) var locale: String
    private static let syncInterval: TimeInterval = 15 * 60

    private(set) var book: PresenterLineBook
    private let session = URLSession(configuration: .ephemeral)
    private var lastSyncAttempt: Date?
    private var syncing = false

    init(locale requestedLocale: String? = nil) {
        let locale = Self.normalized(requestedLocale ?? Locale.preferredLanguages.first ?? "en")
        self.locale = locale
        book = PresenterLineBook.builtIn(locale: locale)
        reloadLocalBook()
    }

    func selectLocale(_ locale: String) {
        let next = Self.normalized(locale)
        guard next != self.locale else { return }
        self.locale = next
        lastSyncAttempt = nil
        reloadLocalBook()
    }

    /// Local file for a clip — bundled or synced — or nil when absent.
    func localURL(for clip: PresenterLineBook.Clip) -> URL? {
        if let bundled = Self.bundledClipURL(clip.sha256) { return bundled }
        guard let synced = Self.clipsFolder?.appendingPathComponent("\(clip.sha256).mp3"),
              FileManager.default.fileExists(atPath: synced.path) else { return nil }
        return synced
    }

    /// Returns true when a newer book was installed.
    @discardableResult
    func sync(force: Bool = false) async -> Bool {
        guard let backend = PresenterBackend.configured, !syncing else { return false }
        if !force, let last = lastSyncAttempt, Date().timeIntervalSince(last) < Self.syncInterval { return false }
        syncing = true
        lastSyncAttempt = Date()
        defer { syncing = false }

        var request = backend.request("api/ays/presenter/pack", query: [
            URLQueryItem(name: "locale", value: locale),
            URLQueryItem(name: "format", value: String(PresenterLineBook.supportedFormat)),
        ], timeout: 10)
        if let etag = storedETag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let candidate = PresenterLineBook.decode(data), candidate.locale == locale,
              let clipsFolder = Self.clipsFolder else { return false }

        for clip in candidate.lines.values.flatMap({ $0 }).compactMap(\.clip) where localURL(for: clip) == nil {
            guard await download(clip, into: clipsFolder, backend: backend) else { return false }
        }

        guard let manifestURL else { return false }
        do { try data.write(to: manifestURL, options: .atomic) } catch { return false }
        storedETag = http.value(forHTTPHeaderField: "ETag")
        removeUnreferencedClips(keeping: candidate.clipHashes, in: clipsFolder)

        let changed = candidate != book
        book = candidate
        return changed
    }

    private func download(_ clip: PresenterLineBook.Clip, into folder: URL, backend: PresenterBackend) async -> Bool {
        let request = backend.request("api/ays/presenter/pack/clips/\(clip.sha256)", timeout: 20)
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              data.count == clip.bytes,
              SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == clip.sha256
        else { return false }
        return (try? data.write(to: folder.appendingPathComponent("\(clip.sha256).mp3"), options: .atomic)) != nil
    }

    private func removeUnreferencedClips(keeping referenced: Set<String>, in folder: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for file in files where !referenced.contains(file.deletingPathExtension().lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    // MARK: - Storage

    /// tvOS has no guaranteed persistent storage; Caches may be purged, in
    /// which case the bundled pack takes over until the next sync.
    private static var rootFolder: URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let folder = caches.appendingPathComponent("PresenterPack", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private static var clipsFolder: URL? {
        guard let folder = rootFolder?.appendingPathComponent("clips", isDirectory: true) else { return nil }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private var manifestURL: URL? { Self.rootFolder?.appendingPathComponent("manifest.\(locale).json") }

    private var storedETag: String? {
        get { UserDefaults.standard.string(forKey: "presenterPack.etag.\(locale)") }
        set { UserDefaults.standard.set(newValue, forKey: "presenterPack.etag.\(locale)") }
    }

    private func loadSynced() -> PresenterLineBook? {
        guard let url = manifestURL, let data = try? Data(contentsOf: url),
              let book = PresenterLineBook.decode(data),
              let folder = Self.clipsFolder else { return nil }
        // A purged Caches folder can leave a manifest whose clips are gone.
        let complete = book.clipHashes.allSatisfy {
            Self.bundledClipURL($0) != nil || FileManager.default.fileExists(atPath: folder.appendingPathComponent("\($0).mp3").path)
        }
        if !complete { storedETag = nil }
        return complete ? book : nil
    }

    private func loadBundled() -> PresenterLineBook? {
        guard let url = Bundle.main.url(forResource: "manifest.\(locale)", withExtension: "json", subdirectory: "PresenterPack")
                ?? Bundle.main.url(forResource: "manifest.\(locale)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let book = PresenterLineBook.decode(data),
              book.locale == locale, book.clipHashes.allSatisfy({ Self.bundledClipURL($0) != nil }) else { return nil }
        return book
    }

    private func reloadLocalBook() {
        let synced = loadSynced()
        let bundled = loadBundled()
        book = [synced, bundled].compactMap { $0 }.max { $0.revision < $1.revision }
            ?? PresenterLineBook.builtIn(locale: locale)
    }

    static func normalized(_ raw: String) -> String {
        let code = raw.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? "en"
        return OfflinePresenterPack.supportedLocales.contains(code) ? code : "en"
    }

    private static func bundledClipURL(_ sha256: String) -> URL? {
        Bundle.main.url(forResource: sha256, withExtension: "mp3", subdirectory: "PresenterPack")
            ?? Bundle.main.url(forResource: sha256, withExtension: "mp3")
    }
}
