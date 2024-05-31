/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *  https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#import "ViewController.h"

#import <AVKit/AVKit.h>

#import <GoogleInteractiveMediaAds/GoogleInteractiveMediaAds.h>

// Enum for stream request type, below
typedef enum {kLiveStream, kVODStream} streamType;

/// Podserving stream request type. Either kLiveStream or kVODStream.
static streamType const kRequestType = kLiveStream;
/// Podserving stream Network Code.
static NSString *const kNetworkCode = @"";
/// Podserving custom asset key. For live streams only.
static NSString *const kCustomAssetKey = @"";
/// Podserving VTP API
static NSString *(^gCustomVTPParser)(NSString *) = ^(NSString *streamID) {
  // Insert synchronous code here to retrieve a stream manifest URL from your video tech partner
  // or manifest manipulation server.
  NSString *manifestUrl = @"";
  return manifestUrl;
};

/// Fallback URL in case something goes wrong in loading the stream. If all goes well, this will not
/// be used.
static NSString *const kBackupStreamURLString = @"";

@interface ViewController () <IMAAdsLoaderDelegate,
                              IMAStreamManagerDelegate,
                              AVPlayerViewControllerDelegate>
@property(nonatomic) IMAAdsLoader *adsLoader;
@property(nonatomic) IMAAdDisplayContainer *adDisplayContainer;
@property(nonatomic) UIView *adContainerView;
@property(nonatomic) id<IMAVideoDisplay> videoDisplay;
@property(nonatomic) IMAStreamManager *streamManager;
@property(nonatomic) AVPlayerViewController *playerViewController;
@property(nonatomic, getter=isAdBreakActive) BOOL adBreakActive;
@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = [UIColor blackColor];
  [self setupAdsLoader];
  [self setupPlayer];
  [self setupAdContainer];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [self requestStream];
}

- (void)setupAdsLoader {
  self.adsLoader = [[IMAAdsLoader alloc] init];
  self.adsLoader.delegate = self;
}

- (void)setupPlayer {
  // Create a stream video player.
  AVPlayer *player = [[AVPlayer alloc] init];
  self.playerViewController = [[AVPlayerViewController alloc] init];
  self.playerViewController.player = player;

  // Attach video player to view hierarchy.
  [self addChildViewController:self.playerViewController];
  [self.view addSubview:self.playerViewController.view];
  self.playerViewController.view.frame = self.view.bounds;
  [self.playerViewController didMoveToParentViewController:self];
}

- (void)setupAdContainer {
  // Attach the ad container to the view hierarchy on top of the player.
  self.adContainerView = [[UIView alloc] init];
  [self.view addSubview:self.adContainerView];
  self.adContainerView.frame = self.view.bounds;
  // Keep hidden initially, until an ad break.
  self.adContainerView.hidden = YES;
}

- (void)requestStream {
  self.videoDisplay =
      [[IMAAVPlayerVideoDisplay alloc] initWithAVPlayer:self.playerViewController.player];
  self.adDisplayContainer = [[IMAAdDisplayContainer alloc] initWithAdContainer:self.adContainerView
                                                                viewController:self];
  if (kRequestType == kLiveStream) {
    // Podserving live stream request.
    IMAPodStreamRequest *request =
        [[IMAPodStreamRequest alloc] initWithNetworkCode:kNetworkCode
                                          customAssetKey:kCustomAssetKey
                                      adDisplayContainer:self.adDisplayContainer
                                            videoDisplay:self.videoDisplay
                                   pictureInPictureProxy:nil
                                             userContext:nil];
    [self.adsLoader requestStreamWithRequest:request];
  } else {
    // Podserving VOD stream request.
    IMAPodVODStreamRequest *request =
        [[IMAPodVODStreamRequest alloc] initWithNetworkCode:kNetworkCode
                                         adDisplayContainer:self.adDisplayContainer
                                               videoDisplay:self.videoDisplay
                                      pictureInPictureProxy:nil
                                                userContext:nil];
    [self.adsLoader requestStreamWithRequest:request];
  }
}

- (void)playBackupStream {
  NSURL *backupStreamURL = [NSURL URLWithString:kBackupStreamURLString];
  [self.videoDisplay loadStream:backupStreamURL withSubtitles:@[]];
  [self.videoDisplay play];
  [self startMediaSession];
}

- (void)startMediaSession {
  [[AVAudioSession sharedInstance] setActive:YES error:nil];
  [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
}

#pragma mark - UIFocusEnvironment

- (NSArray<id<UIFocusEnvironment>> *)preferredFocusEnvironments {
  if (self.isAdBreakActive && self.adDisplayContainer.focusEnvironment) {
    // Send focus to the ad display container during an ad break.
    return @[ self.adDisplayContainer.focusEnvironment ];
  } else {
    // Send focus to the content player otherwise.
    return @[ self.playerViewController ];
  }
}

#pragma mark - IMAAdsLoaderDelegate

- (void)adsLoader:(IMAAdsLoader *)loader adsLoadedWithData:(IMAAdsLoadedData *)adsLoadedData {
  // Initialize and listen to stream manager's events.
  self.streamManager = adsLoadedData.streamManager;
  // The stream manager must be initialized before playback for adsRenderingSettings to be
  // respected.
  [self.streamManager initializeWithAdsRenderingSettings:nil];
  self.streamManager.delegate = self;

  // Build the Podserving Stream URL and load into AVPlayer
  NSString *streamId = adsLoadedData.streamManager.streamId;
  NSString *urlString = gCustomVTPParser(streamId);
  NSURL *streamUrl = [NSURL URLWithString:urlString];
  if (kRequestType == kLiveStream) {
    [self.videoDisplay loadStream:streamUrl withSubtitles:@[]];
    [self.videoDisplay play];
  } else {
    [self.streamManager loadThirdPartyStream:streamUrl streamSubtitles:@[]];
    // There is no need to trigger playback here.
    // streamManager.loadThirdPartyStream will load the stream, request metadata, and play
  }
  NSLog(@"Stream created with: %@.", self.streamManager.streamId);
}

- (void)adsLoader:(IMAAdsLoader *)loader failedWithErrorData:(IMAAdLoadingErrorData *)adErrorData {
  // Fall back to playing the backup stream.
  NSLog(@"Error loading ads: %@", adErrorData.adError.message);
  [self playBackupStream];
}

#pragma mark - IMAStreamManagerDelegate

- (void)streamManager:(IMAStreamManager *)streamManager didReceiveAdEvent:(IMAAdEvent *)event {
  NSLog(@"StreamManager event (%@).", event.typeString);
  switch (event.type) {
    case kIMAAdEvent_STREAM_STARTED: {
      [self startMediaSession];
      break;
    }
    case kIMAAdEvent_STARTED: {
      // Log extended data.
      NSString *extendedAdPodInfo = [[NSString alloc]
          initWithFormat:@"Showing ad %zd/%zd, bumper: %@, title: %@, description: %@, contentType:"
                         @"%@, pod index: %zd, time offset: %lf, max duration: %lf.",
                         event.ad.adPodInfo.adPosition, event.ad.adPodInfo.totalAds,
                         event.ad.adPodInfo.isBumper ? @"YES" : @"NO", event.ad.adTitle,
                         event.ad.adDescription, event.ad.contentType, event.ad.adPodInfo.podIndex,
                         event.ad.adPodInfo.timeOffset, event.ad.adPodInfo.maxDuration];

      NSLog(@"%@", extendedAdPodInfo);
      break;
    }
    case kIMAAdEvent_AD_BREAK_STARTED: {
      self.adContainerView.hidden = NO;
      // Trigger an update to send focus to the ad display container.
      self.adBreakActive = YES;
      [self setNeedsFocusUpdate];
      break;
    }
    case kIMAAdEvent_AD_BREAK_ENDED: {
      self.adContainerView.hidden = YES;
      // Trigger an update to send focus to the content player.
      self.adBreakActive = NO;
      [self setNeedsFocusUpdate];
      break;
    }
    case kIMAAdEvent_ICON_FALLBACK_IMAGE_CLOSED: {
      // Resume playback after the user has closed the dialog.
      [self.videoDisplay play];
      break;
    }
    default:
      break;
  }
}

- (void)streamManager:(IMAStreamManager *)streamManager didReceiveAdError:(IMAAdError *)error {
  // Fall back to playing the backup stream.
  NSLog(@"StreamManager error: %@", error.message);
  [self playBackupStream];
}

#pragma mark - AVPlayerViewControllerDelegate

- (CMTime)playerViewController:(AVPlayerViewController *)playerViewController
    timeToSeekAfterUserNavigatedFromTime:(CMTime)oldTime
                                  toTime:(CMTime)targetTime {
  if (self.isAdBreakActive) {
    // Disable seeking during ad breaks.
    return oldTime;
  }
  return targetTime;
}

@end
