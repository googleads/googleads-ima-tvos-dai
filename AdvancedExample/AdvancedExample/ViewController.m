#import "ViewController.h"

@import AVKit;
@import InteractiveMediaAds;

#import "AdUI.h"

// VOD content source and video IDs.
static NSString *const kContentSourceID = @"19463";
static NSString *const kVideoID = @"googleio-highlights";

static NSString *const kBackupContentPath =
    @"http://googleimadev-vh.akamaihd.net/i/big_buck_bunny/bbb-,480p,720p,1080p,.mov.csmil/"
    @"master.m3u8";

@interface ViewController () <IMAStreamManagerDelegate, AVPlayerViewControllerDelegate>

/// Reference to the Ad UI.
@property(nonatomic, strong) AdUI *adUI;

/// Holds the AVPlayer for stream playback.
@property(nonatomic, strong) AVPlayerViewController *playerViewController;

/// Used to provide the IMA SDK with a reference to the AVPlayer.
@property(nonatomic, strong) IMAAVPlayerVideoDisplay *videoDisplay;

/// Main point of interaction with the SDK - used to request the stream, and calls delegate methods
/// once the stream has been initialized.
@property(nonatomic, strong) IMAStreamManager *streamManager;

/// Cue points of the ad breaks in the stream.
@property(nonatomic, copy) NSArray<IMACuepoint *> *cuepoints;

/// Bookmark time for resuming from time we left off.
@property(nonatomic, assign) NSTimeInterval bookmarkTime;

/// Time the user was trying to seek to before snapback.
@property(nonatomic, assign) NSTimeInterval userSeekTime;

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
  // Save bookmark time.
  if (!self.streamManager) {
    return;
  }

  self.bookmarkTime = [self.streamManager contentTimeForStreamTime:CMTimeGetSeconds(
      self.playerViewController.player.currentTime)];
}

- (void)playBackupStream {
  NSURL *contentURL = [NSURL URLWithString:kBackupContentPath];
  self.playerViewController.player = [[AVPlayer alloc] initWithURL:contentURL];
  [self.playerViewController.player play];
}

- (IBAction)buttonPressed:(id)sender {
  self.playerViewController = [[AVPlayerViewController alloc] init];
  self.playerViewController.player = [[AVPlayer alloc] init];
  self.playerViewController.delegate = self;

  self.videoDisplay = [[IMAAVPlayerVideoDisplay alloc]
      initWithAVPlayer:self.playerViewController.player];

  IMAVODStreamRequest *streamRequest =
  [[IMAVODStreamRequest alloc] initWithContentSourceID:kContentSourceID videoID:kVideoID];

  self.streamManager = [[IMAStreamManager alloc] initWithVideoDisplay:self.videoDisplay];
  self.streamManager.delegate = self;

  [self.streamManager requestStream:streamRequest];

  self.adUI = [[AdUI alloc] init];
  [self.playerViewController.view addSubview:self.adUI];
  self.adUI.frame = self.view.bounds;

  [self presentViewController:self.playerViewController animated:false completion:nil];
}


#pragma mark - Stream manager delegates

- (void)streamManager:(IMAStreamManager *)streamManager didReceiveError:(NSError *)error {
  NSLog(@"Error: %@", error.localizedDescription);
  [self playBackupStream];
}

- (void)streamManager:(IMAStreamManager *)streamManager didInitializeStream:(NSString *)streamID {
  NSLog(@"Stream initialized with streamID: %@", streamID);
}

- (void)streamManager:(IMAStreamManager *)streamManager
      adBreakDidStart:(IMAAdBreakInfo *)adBreakInfo {
  NSLog(@"Stream manager event (ad break start)");
  self.playerViewController.requiresLinearPlayback = YES;
  self.adUI.hidden = NO;
}

- (void)streamManager:(IMAStreamManager *)streamManager adDidStart:(IMAAd *)ad {
  NSLog(@"Stream manager event (start)");
  NSString *adInfo = [NSString stringWithFormat:@"Showing ad %ld/%ld, title: %@, description: %@",
                      ad.adPosition, ad.adBreakInfo.totalAds, ad.adTitle, ad.adDescription];
  NSLog(@"%@", adInfo);
  [self.adUI updateAdPosition:ad.adPosition totalAds:ad.adBreakInfo.totalAds];
}

- (void)streamManager:(IMAStreamManager *)streamManager
        adBreakDidEnd:(IMAAdBreakInfo *)adBreakInfo {
  NSLog(@"Stream manager event (ad break complete)");
  self.playerViewController.requiresLinearPlayback = NO;
  self.adUI.hidden = YES;
  if (self.userSeekTime > 0) {
    [self.playerViewController.player
                    seekToTime:CMTimeMakeWithSeconds(self.userSeekTime, NSEC_PER_SEC)
               toleranceBefore:kCMTimeZero
                toleranceAfter:kCMTimeZero];
    self.userSeekTime = 0;
  }
}

- (void)streamManager:(IMAStreamManager *)streamManager
   didUpdateCuepoints:(NSArray<IMACuepoint *> *)cuepoints {
  self.cuepoints = cuepoints;
}

- (void)streamManager:(IMAStreamManager *)streamManager
                   ad:(IMAAd *)ad
       didCountdownTo:(NSTimeInterval)remainingTime {
  [self.adUI updateCountdownTimer:remainingTime];
}

- (void)streamManagerIsPlaybackReady:(IMAStreamManager *)streamManager {
  if (!self.cuepoints || !self.cuepoints.count) {
    return;
  }
  NSMutableArray<AVInterstitialTimeRange *> *timeRanges = [NSMutableArray array];
  for (IMACuepoint *cuepoint in self.cuepoints) {
    CMTime startTime = CMTimeMake(cuepoint.startTime, 1);
    CMTime duration = CMTimeMake(cuepoint.endTime - cuepoint.startTime, 1);
    CMTimeRange timeRange = CMTimeRangeMake(startTime, duration);
    AVInterstitialTimeRange *interstitialRange =
    [[AVInterstitialTimeRange alloc] initWithTimeRange:timeRange];
    [timeRanges addObject:interstitialRange];
  }
  self.playerViewController.player.currentItem.interstitialTimeRanges = timeRanges;
  if (self.bookmarkTime != 0) {
    NSTimeInterval streamTime = [self.streamManager streamTimeForContentTime:self.bookmarkTime];
    [self.playerViewController.player seekToTime:CMTimeMakeWithSeconds(streamTime, NSEC_PER_SEC)];
  }
}

#pragma mark - AVPlayerViewController delegates

- (void)playerViewController:(AVPlayerViewController *)playerViewController
  willResumePlaybackAfterUserNavigatedFromTime:(CMTime)oldTime
                      toTime:(CMTime)targetTime {
  if (self.streamManager) {
    IMACuepoint *prevCuepoint = [self.streamManager
        previousCuepointForStreamTime:CMTimeGetSeconds(targetTime)];
    if (prevCuepoint && !prevCuepoint.isPlayed) {
      self.userSeekTime = CMTimeGetSeconds(targetTime);
      [self.playerViewController.player seekToTime:CMTimeMakeWithSeconds(
                 prevCuepoint.startTime, NSEC_PER_SEC)
                 toleranceBefore:kCMTimeZero
                  toleranceAfter:kCMTimeZero];
    }
  }
}

@end
