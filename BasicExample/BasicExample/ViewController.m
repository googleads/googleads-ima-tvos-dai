#import "ViewController.h"

@import AVKit;
@import InteractiveMediaAds;

// Live stream asset key.
static NSString *const kAssetKey = @"sN_IYUG8STe1ZzhIIE_ksA";
// VOD content source and video IDs.
static NSString *const kContentSourceID = @"19463";
static NSString *const kVideoID = @"googleio-highlights";

static NSString *const kBackupContentPath =
    @"http://googleimadev-vh.akamaihd.net/i/big_buck_bunny/bbb-,480p,720p,1080p,.mov.csmil/"
    @"master.m3u8";

@interface ViewController () <IMAStreamManagerDelegate>

/// Holds the AVPlayer for stream playback.
@property(nonatomic, strong) AVPlayerViewController *playerViewController;

/// Used to provide the IMA SDK with a reference to the AVPlayer.
@property(nonatomic, strong) IMAAVPlayerVideoDisplay *videoDisplay;

/// Main point of interaction with the SDK - used to request the stream, and calls delegate methods
/// once the stream has been initialized.
@property(nonatomic, strong) IMAStreamManager *streamManager;

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  self.playerViewController = [[AVPlayerViewController alloc] init];
  self.playerViewController.player = [[AVPlayer alloc] init];

  self.videoDisplay =
      [[IMAAVPlayerVideoDisplay alloc] initWithAVPlayer:self.playerViewController.player];

  // Create a stream request. Use one of "Live stream request" or "VOD request".
  // Live stream request.
  IMALiveStreamRequest *streamRequest = [[IMALiveStreamRequest alloc] initWithAssetKey:kAssetKey];
  // VOD request. Comment out the IMALiveStreamRequest above and uncomment this IMAVODStreamRequest
  // to switch from a livestream to a VOD stream.
  /*IMAVODStreamRequest *streamRequest =
      [[IMAVODStreamRequest alloc] initWithContentSourceID:kContentSourceID videoID:kVideoID];*/

  self.streamManager = [[IMAStreamManager alloc] initWithVideoDisplay:self.videoDisplay];
  self.streamManager.delegate = self;

  [self.streamManager requestStream:streamRequest];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [self presentViewController:self.playerViewController animated:false completion:nil];
}

- (void)playBackupStream {
  NSURL *contentURL = [NSURL URLWithString:kBackupContentPath];
  self.playerViewController.player = [[AVPlayer alloc] initWithURL:contentURL];
  [self.playerViewController.player play];
}

#pragma mark - Stream manager delegates

- (void)streamManager:(IMAStreamManager *)streamManager didReceiveError:(NSError *)error {
  NSLog(@"Error: %@", error);
  [self playBackupStream];
}

- (void)streamManager:(IMAStreamManager *)streamManager didInitializeStream:(NSString *)streamID {
  NSLog(@"Stream initialized with streamID: %@", streamID);
}

- (void)streamManager:(IMAStreamManager *)streamManager
      adBreakDidStart:(IMAAdBreakInfo *)adBreakInfo {
  NSLog(@"Stream manager event (ad break start)");
  self.playerViewController.requiresLinearPlayback = YES;
}

- (void)streamManager:(IMAStreamManager *)streamManager
        adBreakDidEnd:(IMAAdBreakInfo *)adBreakInfo {
  NSLog(@"Stream manager event (ad break complete)");
  self.playerViewController.requiresLinearPlayback = NO;
}

@end
