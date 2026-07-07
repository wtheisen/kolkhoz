import Cocoa
import FlutterMacOS

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
