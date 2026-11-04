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
//    { "available": true, "status": <UIHinge.Status raw 0...3>, "angle": <radians> }
//    { "available": false }   // the interaction left a hinge-aware hierarchy
//  Nothing is ever sent before iOS 27.1 or on a device whose hierarchy
//  provides no hinge updates: Dart then stays at "no foldable capability".
//

import Flutter
import UIKit

final class HingeController: NSObject, FlutterStreamHandler {
  private let channel: FlutterEventChannel
  private var sink: FlutterEventSink?
  /// `UIHingeInteraction` on iOS 27.1+, typed loosely so the class still
  /// compiles for the 17.6 deployment target.
  private var interaction: AnyObject?
  private weak var hostView: UIView?
  private var attachAttempts = 0

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterEventChannel(name: "ays/foldable/hinge", binaryMessenger: messenger)
    super.init()
    channel.setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    attachAttempts = 0
    DispatchQueue.main.async { [weak self] in self?.attach() }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    detach()
    sink = nil
    return nil
  }

  private func attach() {
    guard sink != nil, interaction == nil else { return }
    guard #available(iOS 27.1, *) else { return }
    guard let view = Self.flutterRootView() else {
      // The window may not exist yet at engine start; retry briefly.
      attachAttempts += 1
      if attachAttempts < 20 {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.attach() }
      }
      return
    }
    let hinge = UIHingeInteraction { [weak self] _, update in
      self?.send(update.hinge)
    }
    view.addInteraction(hinge)
    interaction = hinge
    hostView = view
  }

  @available(iOS 27.1, *)
  private func send(_ hinge: UIHinge?) {
    guard let sink else { return }
    guard let hinge else {
      sink(["available": false])
      return
    }
    sink([
      "available": true,
      "status": hinge.status.rawValue,
      "angle": Double(hinge.angle),
    ])
  }

  private func detach() {
    if #available(iOS 27.1, *), let hinge = interaction as? UIHingeInteraction {
      hostView?.removeInteraction(hinge)
    }
    interaction = nil
    hostView = nil
  }

  private static func flutterRootView() -> UIView? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    return (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController?.view
  }
}
