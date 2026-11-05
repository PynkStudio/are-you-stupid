import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var appleAIController: AppleAIController?
  private var permissionsController: PermissionsController?
  private var hingeController: HingeController?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Overrides Info.plist's portrait-only list, for iPhone Duo's cover display.
  // Info.plist stays portrait so no other iPhone can launch sideways.
  override func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    if UIDevice.current.userInterfaceIdiom == .pad {
      return [.portrait, .portraitUpsideDown]
    }
    return hingeController?.hasHinge == true ? .allButUpsideDown : .portrait
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Phase 2 of the Dynamic AI Director: register the on-device model bridge
    // (docs/AI/Foundation Models Integration.md). Retained for app lifetime.
    appleAIController = AppleAIController(messenger: engineBridge.applicationRegistrar.messenger())
    // Multiplayer permissions UX: Local Network probe + open Settings
    // (docs/Architecture/Multiplayer Client (Mobile).md, "Permissions").
    permissionsController = PermissionsController(messenger: engineBridge.applicationRegistrar.messenger())
    // Unfold Your Brain: public iOS 27.1 hinge state → Dart
    // (docs/Foldable/Foldable Architecture.md).
    hingeController = HingeController(messenger: engineBridge.applicationRegistrar.messenger())
  }
}
