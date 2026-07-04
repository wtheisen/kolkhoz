import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    self.title = "Kolkhoz"
    self.isRestorable = false
    self.minSize = NSSize(width: 800, height: 600)
    self.setAccessibilityElement(true)
    self.setAccessibilityRole(.window)
    self.setAccessibilitySubrole(.standardWindow)
    self.setAccessibilityTitle("Kolkhoz")
    self.placeForInitialLaunch()

    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    self.makeKeyAndOrderFront(nil)
    self.orderFrontRegardless()
    NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

    DispatchQueue.main.async {
      self.placeForInitialLaunch()
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.placeForInitialLaunch()
    }
  }
}

extension MainFlutterWindow {
  func placeForInitialLaunch() {
    let targetScreen = NSScreen.screens.max { left, right in
      left.frame.maxX < right.frame.maxX
    } ?? NSScreen.main

    guard let screen = targetScreen else { return }

    let frame = NSRect(
      x: screen.visibleFrame.midX - 600,
      y: screen.visibleFrame.midY - 400,
      width: 1200,
      height: 800
    )
    self.setFrame(frame, display: true)
    self.makeKeyAndOrderFront(nil)
    self.orderFrontRegardless()
  }
}
