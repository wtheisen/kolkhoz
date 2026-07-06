#import "AppDelegate.h"

#import "MainFlutterWindow.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
  [NSApp unhide:nil];
  [[NSRunningApplication currentApplication] activateWithOptions:NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps];

  dispatch_async(dispatch_get_main_queue(), ^{
    for (NSWindow *window in [NSApp windows]) {
      if ([window isKindOfClass:[MainFlutterWindow class]]) {
        [(MainFlutterWindow *)window placeForInitialLaunch];
      }
    }
  });
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
  return YES;
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
  return NO;
}

@end
