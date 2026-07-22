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
      let authenticationTimeout = DispatchWorkItem {
        guard !completed else { return }
        completed = true
        GKLocalPlayer.local.authenticateHandler = nil
        NSLog("Game Center authentication timed out after 30 seconds.")
        result(FlutterError(
          code: "game_center_timeout",
          message: "Game Center authentication timed out.",
          details: nil
        ))
      }
      DispatchQueue.main.asyncAfter(
        deadline: .now() + 30,
        execute: authenticationTimeout
      )

      func complete(_ value: Any?) {
        guard !completed else { return }
        completed = true
        authenticationTimeout.cancel()
        GKLocalPlayer.local.authenticateHandler = nil
        result(value)
      }

      GKLocalPlayer.local.authenticateHandler = { viewController, error in
        if let viewController {
          self?.contentViewController?.presentAsModalWindow(viewController)
          return
        }
        if let error = error as NSError? {
          NSLog(
            "Game Center authentication failed: %@ (%@ %ld)",
            error.localizedDescription,
            error.domain,
            error.code
          )
          complete(FlutterError(
            code: "game_center_authentication",
            message: error.localizedDescription,
            details: ["domain": error.domain, "code": error.code]
          ))
          return
        }
        guard GKLocalPlayer.local.isAuthenticated else {
          complete(nil)
          return
        }
        guard #available(macOS 10.15.5, *) else {
          complete(FlutterError(
            code: "game_center_unavailable",
            message: "Game Center requires macOS 10.15.5 or newer.",
            details: nil
          ))
          return
        }
        GKLocalPlayer.local.fetchItems(forIdentityVerificationSignature: {
          publicKeyURL, signature, salt, timestamp, signatureError in
          guard !completed else { return }
          guard signatureError == nil,
                let publicKeyURL,
                let signature,
                let salt else {
            if let signatureError = signatureError as NSError? {
              NSLog(
                "Game Center verification failed: %@ (%@ %ld)",
                signatureError.localizedDescription,
                signatureError.domain,
                signatureError.code
              )
            }
            complete(FlutterError(
              code: "game_center",
              message: "Game Center verification failed.",
              details: nil
            ))
            return
          }
          complete([
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
