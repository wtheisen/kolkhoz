import Cocoa
import FlutterMacOS
import GameKit

@objc(MainFlutterWindow)
class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    title = "Kolkhoz"
    isRestorable = false
    minSize = NSSize(width: 390, height: 600)
    setAccessibilityElement(true)
    setAccessibilityRole(.window)
    setAccessibilitySubrole(.standardWindow)
    setAccessibilityTitle("Kolkhoz")
    placeForInitialLaunch()

    let flutterViewController = FlutterViewController()
    let windowFrame = frame
    contentViewController = flutterViewController
    setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let identityChannel = FlutterMethodChannel(
      name: "com.williamtheisen.kolkhoz/identity",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    identityChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "authenticateGameCenter" else {
        result(FlutterMethodNotImplemented)
        return
      }
      var completed = false
      GKLocalPlayer.local.authenticateHandler = { viewController, error in
        if let viewController {
          self?.contentViewController?.presentAsModalWindow(viewController)
          return
        }
        guard !completed else { return }
        guard error == nil, GKLocalPlayer.local.isAuthenticated else {
          completed = true
          result(nil)
          return
        }
        guard #available(macOS 10.15.5, *) else {
          completed = true
          result(FlutterError(
            code: "game_center_unavailable",
            message: "Game Center requires macOS 10.15.5 or newer.",
            details: nil
          ))
          return
        }
        GKLocalPlayer.local.fetchItems(forIdentityVerificationSignature: {
          publicKeyURL, signature, salt, timestamp, signatureError in
          guard !completed else { return }
          completed = true
          guard signatureError == nil,
                let publicKeyURL,
                let signature,
                let salt else {
            result(FlutterError(
              code: "game_center",
              message: "Game Center verification failed.",
              details: nil
            ))
            return
          }
          result([
            "teamPlayerID": GKLocalPlayer.local.teamPlayerID,
            "publicKeyURL": publicKeyURL.absoluteString,
            "signature": signature.base64EncodedString(),
            "salt": salt.base64EncodedString(),
            "timestamp": timestamp,
          ])
        })
      }
    }

    super.awakeFromNib()

    makeKeyAndOrderFront(nil)
    orderFrontRegardless()
    NSRunningApplication.current.activate(options: [
      .activateAllWindows,
      .activateIgnoringOtherApps,
    ])

    DispatchQueue.main.async {
      self.placeForInitialLaunch()
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.placeForInitialLaunch()
    }
  }

  @objc func placeForInitialLaunch() {
    var targetScreen: NSScreen?
    for screen in NSScreen.screens {
      if targetScreen == nil || screen.frame.maxX > targetScreen!.frame.maxX {
        targetScreen = screen
      }
    }
    if targetScreen == nil {
      targetScreen = NSScreen.main
    }
    guard let visibleFrame = targetScreen?.visibleFrame else {
      return
    }

    let frame = NSRect(
      x: visibleFrame.midX - 600,
      y: visibleFrame.midY - 400,
      width: 1200,
      height: 800
    )
    setFrame(frame, display: true)
    makeKeyAndOrderFront(nil)
    orderFrontRegardless()
  }
}
