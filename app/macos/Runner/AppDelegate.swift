import Cocoa
import FlutterMacOS

@main
@objc(AppDelegate)
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.unhide(nil)
    NSRunningApplication.current.activate(options: [
      .activateAllWindows,
      .activateIgnoringOtherApps,
    ])

    DispatchQueue.main.async {
      for window in NSApp.windows {
        if let window = window as? MainFlutterWindow {
          window.placeForInitialLaunch()
        }
      }
    }

    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(
    _ sender: NSApplication
  ) -> Bool {
    true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    false
  }
}
