//
//  HingeController.swift
//  Runner
//
//  UNFOLD YOUR BRAIN — the native half of the foldable hardware layer
//  (docs/Foldable/Foldable Architecture.md).
//
//  Streams the public iOS 27.1 hinge state (`UIHinge` via
//  `UIHingeInteraction`, UIKit/UIHinge.h + UIHingeInteraction.h) to Dart over
//  the `ays/foldable/hinge` event channel. Raw values only — normalization
//  lives in `lib/core/foldable.dart`, so the simulator and the hardware share
//  one code path above this line.
//
//  Payloads:
//    { "available": true, "status": <UIHinge.Status raw 0...3>, "angle": <radians>,
//      "sizeClass": <UIUserInterfaceSizeClass raw, the view's horizontal class> }
//    { "available": false }   // the interaction left a hinge-aware hierarchy
//  Nothing is ever sent before iOS 27.1 or on a device whose hierarchy
//  provides no hinge updates: Dart then stays at "no foldable capability".
//
//  The interaction lives as long as the app, because the first known status
//  also unlocks rotation: `hasHinge` for AppDelegate, plus a one-off
//  `hingeDetected` call on `ays/foldable` so Dart lifts its portrait lock.
//

import Flutter
import UIKit

final class HingeController: NSObject, FlutterStreamHandler {
  private let channel: FlutterEventChannel
  private let presenceChannel: FlutterMethodChannel
  /// A hinge reported a known status. Never true on a conventional phone.
  private(set) var hasHinge = false
  private var sink: FlutterEventSink?
  /// `UIHingeInteraction` on iOS 27.1+, typed loosely so the class still
  /// compiles for the 17.6 deployment target.
  private var interaction: AnyObject?
  private weak var hostView: UIView?
  /// The latest `UIHinge`, resent when only the size class changes.
  private var lastHinge: AnyObject?
  private var attachAttempts = 0
  private var traitRegistration: UITraitChangeRegistration?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterEventChannel(name: "ays/foldable/hinge", binaryMessenger: messenger)
    presenceChannel = FlutterMethodChannel(name: "ays/foldable", binaryMessenger: messenger)
    super.init()
    channel.setStreamHandler(self)
    DispatchQueue.main.async { [weak self] in
      MainActor.assumeIsolated { self?.attach() }
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    // A new listener (each game screen) starts from the current reading.
    DispatchQueue.main.async { [weak self] in
      MainActor.assumeIsolated { self?.resend() }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  @MainActor
  private func attach() {
    guard interaction == nil else { return }
    guard #available(iOS 27.1, *) else { return }
    guard let view = Self.flutterRootView() else {
      // The window may not exist yet at engine start; retry briefly.
      attachAttempts += 1
      if attachAttempts < 20 {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
          MainActor.assumeIsolated { self?.attach() }
        }
      }
      return
    }
    let hinge = UIHingeInteraction { [weak self] _, update in
      self?.send(update.hinge)
    }
    view.addInteraction(hinge)
    interaction = hinge
    hostView = view
    // Folding is a size class change on the same scene (Apple's iPhone Duo
    // guidance), so it needs its own trigger: the hinge can move without
    // the class changing, and the class can change without the hinge.
    traitRegistration = view.registerForTraitChanges(
      [UITraitHorizontalSizeClass.self]
    ) { [weak self] (_: UIView, _: UITraitCollection) in
      self?.resend()
    }
  }

  @MainActor
  private func resend() {
    guard #available(iOS 27.1, *), let hinge = lastHinge as? UIHinge else { return }
    send(hinge)
  }

  @available(iOS 27.1, *)
  private func send(_ hinge: UIHinge?) {
    lastHinge = hinge
    if let hinge, hinge.status != .unknown, !hasHinge {
      hasHinge = true
      presenceChannel.invokeMethod("hingeDetected", arguments: nil)
    }
    guard let sink else { return }
    guard let hinge else {
      sink(["available": false])
      return
    }
    sink([
      "available": true,
      "status": hinge.status.rawValue,
      "angle": Double(hinge.angle),
      "sizeClass": hostView?.traitCollection.horizontalSizeClass.rawValue ?? 0,
    ])
  }

  @MainActor
  private static func flutterRootView() -> UIView? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    return (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController?.view
  }
}
