import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var appleAIController: AppleAIController?
  private var permissionsController: PermissionsController?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Phase 2 of the Dynamic AI Director: register the on-device model bridge
    // (docs/AI/Foundation Models Integration.md). Retained for app lifetime.
    appleAIController = AppleAIController(messenger: engineBridge.applicationRegistrar.messenger())
    // Multiplayer permissions UX: Local Network probe + open Settings
    // (docs/Architecture/Multiplayer Client (Mobile).md, "Permissions").
    permissionsController = PermissionsController(messenger: engineBridge.applicationRegistrar.messenger())
  }
}
