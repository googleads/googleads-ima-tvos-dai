#import "AppDelegate.h"

#import "IMATVMLCuepoint.h"
#import "IMATVMLPlayerVideoDisplay.h"
#import "Ads.h"

// tvBaseURL points to a server on your local machine. To create a local server for testing
// purposes, use the following command inside your project folder from the Terminal app: ruby -run
// -ehttpd . -p9001. See NSAppTransportSecurity for information on using a non-secure server.
static NSString *const TVBaseURL = @"http://localhost:9001/";
static NSString *const TVBootURL = @"http://localhost:9001/application.js";

@interface AppDelegate ()

@property(nonatomic, strong) IMATVMLPlayerVideoDisplay *videoDisplay;
@property(nonatomic, strong) Ads *adsImpl;

@end

@implementation AppDelegate

#pragma mark UIApplicationDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

  self.videoDisplay = [[IMATVMLPlayerVideoDisplay alloc] init];
  self.adsImpl = [[Ads alloc] initWithVideoDisplay:self.videoDisplay];

  // Create the TVApplicationControllerContext for this application and set the properties that will
  // be passed to the `App.onLaunch` function in JavaScript.
  TVApplicationControllerContext *appControllerContext =
      [[TVApplicationControllerContext alloc] init];
  NSURL *javaScriptURL = [NSURL URLWithString:TVBootURL];
  appControllerContext.javaScriptApplicationURL = javaScriptURL;

  NSMutableDictionary<NSString *, id> *appControllerOptions = [[NSMutableDictionary alloc] init];
  appControllerOptions[@"BASEURL"] = TVBaseURL;
  [appControllerOptions addEntriesFromDictionary:launchOptions];

  appControllerContext.launchOptions = appControllerOptions;
  self.appController = [[TVApplicationController alloc] initWithContext:appControllerContext
                                                                 window:self.window
                                                               delegate:self];

  return YES;
}

#pragma mark TVApplicationControllerDelegate

- (void)appController:(TVApplicationController *)appController
    evaluateAppJavaScriptInContext:(JSContext *)jsContext {
  jsContext[@"videoDisplay"] = self.videoDisplay;
  jsContext[@"ads"] = self.adsImpl;
}

@end
