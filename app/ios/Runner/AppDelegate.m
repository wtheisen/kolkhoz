#import "AppDelegate.h"
#import "GeneratedPluginRegistrant.h"
#import <GameKit/GameKit.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (void)didInitializeImplicitFlutterEngine:(NSObject<FlutterImplicitEngineBridge> *)engineBridge {
  [GeneratedPluginRegistrant registerWithRegistry:engineBridge.pluginRegistry];
  FlutterMethodChannel *channel = [FlutterMethodChannel
      methodChannelWithName:@"com.williamtheisen.kolkhoz/identity"
            binaryMessenger:engineBridge.applicationRegistrar.messenger];
  __weak AppDelegate *weakSelf = self;
  [channel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
    if (![call.method isEqualToString:@"authenticateGameCenter"]) {
      result(FlutterMethodNotImplemented);
      return;
    }
    __block BOOL completed = NO;
    void (^finishAuthentication)(void) = ^{
      if (completed) return;
      if (!GKLocalPlayer.localPlayer.isAuthenticated) {
        NSLog(@"Kolkhoz Game Center authentication unavailable: player is not authenticated");
        completed = YES;
        result(nil);
        return;
      }
      [GKLocalPlayer.localPlayer fetchItemsForIdentityVerificationSignature:
       ^(NSURL *publicKeyURL, NSData *signature, NSData *salt, uint64_t timestamp, NSError *signatureError) {
        if (completed) return;
        completed = YES;
        if (signatureError != nil || publicKeyURL == nil || signature == nil || salt == nil) {
          NSLog(@"Kolkhoz Game Center identity signature unavailable: %@", signatureError.localizedDescription ?: @"missing signature item");
          result([FlutterError errorWithCode:@"game_center"
                                     message:@"Game Center verification failed."
                                     details:nil]);
          return;
        }
        NSLog(@"Kolkhoz Game Center identity signature ready.");
        result(@{
          @"teamPlayerID": GKLocalPlayer.localPlayer.teamPlayerID,
          @"publicKeyURL": publicKeyURL.absoluteString,
          @"signature": [signature base64EncodedStringWithOptions:0],
          @"salt": [salt base64EncodedStringWithOptions:0],
          @"timestamp": @(timestamp),
        });
      }];
    };
    if (GKLocalPlayer.localPlayer.isAuthenticated) {
      finishAuthentication();
      return;
    }
    GKLocalPlayer.localPlayer.authenticateHandler = ^(UIViewController *viewController, NSError *error) {
      if (viewController != nil) {
        UIViewController *root = weakSelf.window.rootViewController;
        [root presentViewController:viewController animated:YES completion:nil];
        return;
      }
      if (completed) return;
      if (error != nil) {
        NSLog(@"Kolkhoz Game Center authentication unavailable: %@", error.localizedDescription);
        completed = YES;
        result(nil);
        return;
      }
      finishAuthentication();
    };
  }];
}

@end
