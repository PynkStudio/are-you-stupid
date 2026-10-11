import Cocoa
import FlutterMacOS
import SwiftUI
import AYSHostUI

class MainFlutterWindow: NSWindow {
  private var hostWindowController: NSWindowController?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let hostChannel = FlutterMethodChannel(
      name: "ays/host_mode",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    hostChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "openHost" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.openHostWindow()
      result(nil)
    }

    super.awakeFromNib()
  }

  private func openHostWindow() {
    if let window = hostWindowController?.window {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let host = NSHostingController(rootView: AYSHostBoardView())
    let window = NSWindow(contentViewController: host)
    window.title = "ARE YOU STUPID? — HOST"
    window.setContentSize(NSSize(width: 1180, height: 760))
    window.minSize = NSSize(width: 900, height: 600)
    window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
    window.center()
    window.isReleasedWhenClosed = false
    hostWindowController = NSWindowController(window: window)
    hostWindowController?.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}
