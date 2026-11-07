// ============================================================================
// cardash_mini2_arm64.m
// TOYOTA PRIUS TRD SPORTIVO GEN 3 — LUXURY EV SMART COCKPIT (iPad mini 2 / ARM64)
// Standalone Native WebKit Container (WKWebView + Hardware Audio + Lock-Free Fullscreen)
// Embeds cardash_trd_preview.html with 100% full visual fidelity matching Safari
// ============================================================================

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreLocation/CoreLocation.h>

@interface TRDCockpitWebViewController : UIViewController <WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate, CLLocationManagerDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) CLLocationManager *locManager;
@end

@implementation TRDCockpitWebViewController

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationLandscapeRight;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.027 green:0.051 blue:0.078 alpha:1.0]; // #070d14
    
    // 1. Keep screen alive indefinitely while driving (No Sleep / No Screen Dim)
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    // 2. Configure Background & Bluetooth Audio Session (Supports In-Car Mixing)
    @try {
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory:AVAudioSessionCategoryPlayback
                      withOptions:(AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionAllowBluetooth)
                            error:nil];
        [audioSession setActive:YES error:nil];
    } @catch (NSException *e) {
        NSLog(@"[AudioSession] Warning: %@", e.reason);
    }
    
    // 3. Initialize Location Manager for GPS Coordinates Bridge
    self.locManager = [[CLLocationManager alloc] init];
    self.locManager.delegate = self;
    self.locManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
    self.locManager.distanceFilter = 1.0;
    if ([self.locManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [self.locManager requestWhenInUseAuthorization];
    }
    [self.locManager startUpdatingLocation];

    // 4. Configure WKWebView for Fullscreen Automotive Cockpit
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.allowsInlineMediaPlayback = YES;
    if (@available(iOS 10.0, *)) {
        config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    }
    config.preferences.javaScriptEnabled = YES;
    [config.preferences setValue:@YES forKey:@"allowFileAccessFromFileURLs"];
    
    self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    self.webView.backgroundColor = [UIColor clearColor];
    self.webView.opaque = NO;
    self.webView.scrollView.bounces = NO;
    self.webView.scrollView.scrollEnabled = NO; // Fixed landscape cockpit viewport
    self.webView.scrollView.showsHorizontalScrollIndicator = NO;
    self.webView.scrollView.showsVerticalScrollIndicator = NO;
    if (@available(iOS 11.0, *)) {
        self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    [self.view addSubview:self.webView];

    // 5. Loading Indicator
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.color = [UIColor colorWithRed:0.0 green:0.82 blue:1.0 alpha:1.0];
    self.spinner.center = self.view.center;
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.spinner.hidesWhenStopped = YES;
    [self.spinner startAnimating];
    [self.view addSubview:self.spinner];

    // 6. Double-tap with 3 fingers to reload page (Diagnostic shortcut)
    UITapGestureRecognizer *tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(reloadCockpit)];
    tripleTap.numberOfTouchesRequired = 3;
    [self.view addGestureRecognizer:tripleTap];

    // 7. Load Cockpit (Local bundle first, then localhost fallback)
    [self loadCockpit];
}

- (void)loadCockpit {
    [self.spinner startAnimating];
    
    // Look for bundled HTML file
    NSURL *localHTML = [[NSBundle mainBundle] URLForResource:@"cardash_trd_preview" withExtension:@"html"];
    if (!localHTML) {
        localHTML = [[NSBundle mainBundle] URLForResource:@"dashboard" withExtension:@"html"];
    }

    if (localHTML) {
        NSLog(@"[CarDash WebKit] Loading bundled cockpit: %@", localHTML.path);
        NSURL *bundleURL = [NSBundle mainBundle].bundleURL;
        [self.webView loadFileURL:localHTML allowingReadAccessToURL:bundleURL];
    } else {
        NSLog(@"[CarDash WebKit] Bundled HTML not found, falling back to local gateway...");
        NSURL *gatewayURL = [NSURL URLWithString:@"http://127.0.0.1:8085/cardash_trd_preview.html"];
        [self.webView loadRequest:[NSURLRequest requestWithURL:gatewayURL]];
    }
}

- (void)reloadCockpit {
    NSLog(@"[CarDash WebKit] 3-finger reload triggered");
    [self.webView reload];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self.spinner stopAnimating];
    NSLog(@"[CarDash WebKit] Cockpit loaded successfully.");
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self.spinner stopAnimating];
    NSLog(@"[CarDash WebKit] Navigation error: %@", error.localizedDescription);
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self.spinner stopAnimating];
    NSLog(@"[CarDash WebKit] Provisional navigation error: %@", error.localizedDescription);
    
    // If local file failed, try remote address fallback
    NSURL *remote = [NSURL URLWithString:@"http://172.20.10.4:8085/cardash_trd_preview.html"];
    [self.webView loadRequest:[NSURLRequest requestWithURL:remote]];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *loc = locations.lastObject;
    if (!loc) return;
    
    // Optionally inject hardware GPS into JavaScript if needed
    double speedKmh = MAX(0.0, loc.speed * 3.6);
    NSString *js = [NSString stringWithFormat:@"if(window.onNativeGPS){window.onNativeGPS(%f,%f,%f,%f);}",
                    loc.coordinate.latitude, loc.coordinate.longitude, loc.course, speedKmh];
    [self.webView evaluateJavaScript:js completionHandler:nil];
}

@end

#pragma mark - App Delegate & Lifecycle

@interface TRDMini2AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation TRDMini2AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[TRDCockpitWebViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([TRDMini2AppDelegate class]));
    }
}
