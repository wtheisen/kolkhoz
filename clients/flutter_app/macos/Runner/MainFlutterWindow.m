#import "MainFlutterWindow.h"

#import <FlutterMacOS/FlutterMacOS.h>

#import "GeneratedPluginRegistrant.h"

@implementation MainFlutterWindow

- (void)awakeFromNib {
  self.title = @"Kolkhoz";
  self.restorable = NO;
  self.minSize = NSMakeSize(800, 600);
  [self setAccessibilityElement:YES];
  [self setAccessibilityRole:NSAccessibilityWindowRole];
  [self setAccessibilitySubrole:NSAccessibilityStandardWindowSubrole];
  [self setAccessibilityTitle:@"Kolkhoz"];
  [self placeForInitialLaunch];

  FlutterViewController *flutterViewController = [[FlutterViewController alloc] init];
  NSRect windowFrame = self.frame;
  self.contentViewController = flutterViewController;
  [self setFrame:windowFrame display:YES];

  RegisterGeneratedPlugins(flutterViewController);

  [super awakeFromNib];

  [self makeKeyAndOrderFront:nil];
  [self orderFrontRegardless];
  [[NSRunningApplication currentApplication] activateWithOptions:NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps];

  dispatch_async(dispatch_get_main_queue(), ^{
    [self placeForInitialLaunch];
  });
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self placeForInitialLaunch];
  });
}

- (void)placeForInitialLaunch {
  NSScreen *targetScreen = nil;
  for (NSScreen *screen in [NSScreen screens]) {
    if (targetScreen == nil || NSMaxX(screen.frame) > NSMaxX(targetScreen.frame)) {
      targetScreen = screen;
    }
  }
  if (targetScreen == nil) {
    targetScreen = [NSScreen mainScreen];
  }
  if (targetScreen == nil) {
    return;
  }

  NSRect visibleFrame = targetScreen.visibleFrame;
  NSRect frame = NSMakeRect(
      NSMidX(visibleFrame) - 600,
      NSMidY(visibleFrame) - 400,
      1200,
      800);
  [self setFrame:frame display:YES];
  [self makeKeyAndOrderFront:nil];
  [self orderFrontRegardless];
}

@end
