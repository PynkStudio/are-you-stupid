//
//  PermissionsController.swift
//  Runner
//
//  Registers the `ays/permissions` MethodChannel used by the multiplayer
//  permissions UX (docs/Architecture/Multiplayer Client (Mobile).md,
//  "Permissions"). Dart side: lib/services/local_network_permission.dart.
//
//  - `localNetworkStatus` -> "granted" | "denied" | "unknown"
//  - `openAppSettings`    -> Bool (opened this app's page in Settings)
//
//  iOS has no API that reads the Local Network permission, so the status is
//  probed (Apple TN3179): browse `_ays-party._tcp` with NWBrowser. `.ready`
//  means allowed; `.waiting`/`.failed` with kDNSServiceErr_PolicyDenied means
//  denied — but iOS reports that same error while its own alert is still on
//  screen. The alert makes the app resign active, so when the app is not
//  active after the settle delay we wait for it to come back before reading
//  the verdict. The browse is also what shows the system prompt the first
//  time, which is why Dart only calls this after its primer.
//

import Flutter
import Network
import UIKit

final class PermissionsController: NSObject {
    static let channelName = "ays/permissions"

    private let channel: FlutterMethodChannel
    private var probes: [LocalNetworkProbe] = []

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "localNetworkStatus":
            let probe = LocalNetworkProbe()
            probes.append(probe)
            probe.start { [weak self, weak probe] status in
                self?.probes.removeAll { $0 === probe }
                result(status)
            }
        case "openAppSettings":
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                result(false)
                return
            }
            UIApplication.shared.open(url) { opened in result(opened) }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

/// One-shot Local Network permission probe. Main-queue only.
private final class LocalNetworkProbe {
    /// kDNSServiceErr_PolicyDenied.
    private static let policyDenied: Int32 = -65570
    /// Long enough for the browser to report a state, short enough to feel instant.
    private static let settle: TimeInterval = 1.5
    /// After the system alert closes, the browser needs a beat to go `.ready`.
    private static let afterAlert: TimeInterval = 1.0
    /// Nobody answers the alert: give up and say "unknown".
    private static let giveUp: TimeInterval = 120

    private var browser: NWBrowser?
    private var completion: ((String) -> Void)?
    private var ready = false
    private var denied = false
    private var activeObserver: NSObjectProtocol?

    func start(_ completion: @escaping (String) -> Void) {
        self.completion = completion
        let browser = NWBrowser(
            for: .bonjour(type: "_ays-party._tcp", domain: nil),
            using: NWParameters())
        browser.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.ready = true
                self.denied = false
            case .waiting(let error), .failed(let error):
                if case .dns(let code) = error, code == Self.policyDenied {
                    self.denied = true
                    self.ready = false
                }
            default:
                break
            }
        }
        browser.start(queue: .main)
        self.browser = browser

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settle) { [weak self] in
            self?.afterSettle()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.giveUp) { [weak self] in
            self?.finish("unknown")
        }
    }

    private func afterSettle() {
        guard completion != nil else { return }
        if UIApplication.shared.applicationState == .active {
            finish(verdict())
            return
        }
        // The system alert is up: read the verdict once the player answers.
        activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.afterAlert) {
                guard let self else { return }
                self.finish(self.verdict())
            }
        }
    }

    private func verdict() -> String {
        if ready { return "granted" }
        if denied { return "denied" }
        return "unknown"
    }

    private func finish(_ status: String) {
        guard let completion else { return }
        self.completion = nil
        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
        }
        activeObserver = nil
        browser?.cancel()
        browser = nil
        completion(status)
    }
}
