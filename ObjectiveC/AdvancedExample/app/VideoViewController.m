/**
 * Copyright 2020 Google LLC
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

#import "VideoViewController.h"

#import <AVKit/AVKit.h>

#import <GoogleInteractiveMediaAds/GoogleInteractiveMediaAds.h>

#import "LiveStream.h"
#import "Stream.h"
#import "VODStream.h"


@interface VideoViewController () <IMAAdsLoaderDelegate,
                                   IMAStreamManagerDelegate,
                                   AVPlayerViewControllerDelegate,
                                   IMAAVPlayerVideoDisplayDelegate>
@property(nonatomic) IMAAdsLoader *adsLoader;
@property(nonatomic) IMAAdDisplayContainer *adDisplayContainer;
@property(nonatomic) UIView *adContainerView;
@property(nonatomic) id<IMAVideoDisplay> videoDisplay;
@property(nonatomic) IMAStreamManager *streamManager;
@property(nonatomic) AVPlayerViewController *playerViewController;
@property(nonatomic) IMAAVPlayerContentPlayhead *contentPlayhead;
@property(nonatomic) CGFloat userSeekTime;
@property(nonatomic, getter=isAdBreakActive) BOOL adBreakActive;
@end

@implementation VideoViewController

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

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];
  [self.playerViewController.player pause];
  [self saveBookmark];
  [self.playerViewController.player replaceCurrentItemWithPlayerItem:NULL];
}

- (void)saveBookmark {
  if ([self.stream isKindOfClass:[VODStream class]]) {
    VODStream *vodStream = (VODStream *)self.stream;
    CMTime cmTime = [self.playerViewController.player currentTime];
    CGFloat streamTime = CMTimeGetSeconds(cmTime);
    CGFloat contentTime = [self.streamManager contentTimeForStreamTime:streamTime];
    vodStream.bookmark = contentTime;
    NSLog(@"saving bookmark: %lf", contentTime);
  }
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

  self.contentPlayhead =
      [[IMAAVPlayerContentPlayhead alloc] initWithAVPlayer:self.playerViewController.player];

  AVPlayerItem *contentPlayerItem = self.playerViewController.player.currentItem;
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(contentDidFinishPlaying)
                                               name:AVPlayerItemDidPlayToEndTimeNotification
                                             object:contentPlayerItem];

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
  if ([self.stream isKindOfClass:[LiveStream class]]) {
    LiveStream *liveStream = (LiveStream *)self.stream;
    IMALiveStreamRequest *request =
        [[IMALiveStreamRequest alloc] initWithAssetKey:liveStream.assetKey
                                    adDisplayContainer:self.adDisplayContainer
                                          videoDisplay:self.videoDisplay];
    [self.adsLoader requestStreamWithRequest:request];
  } else if ([self.stream isKindOfClass:[VODStream class]]) {
    VODStream *vodStream = (VODStream *)self.stream;
    IMAVODStreamRequest *request =
        [[IMAVODStreamRequest alloc] initWithContentSourceID:vodStream.contentID
                                                     videoID:vodStream.videoID
                                          adDisplayContainer:self.adDisplayContainer
                                                videoDisplay:self.videoDisplay];
    [self.adsLoader requestStreamWithRequest:request];
  } else {
    NSLog(@"Error: unknown stream type");
    [self dismissViewControllerAnimated:TRUE completion:NULL];
  }
}

- (void)contentDidFinishPlaying {
  [self.adsLoader contentComplete];
  [self dismissViewControllerAnimated:TRUE completion:NULL];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
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
  // Grab the instance of the IMAAdsManager and set ourselves as the delegate.
  self.streamManager = adsLoadedData.streamManager;
  self.streamManager.delegate = self;
  [self.streamManager initializeWithAdsRenderingSettings:nil];
}

- (void)adsLoader:(IMAAdsLoader *)loader failedWithErrorData:(IMAAdLoadingErrorData *)adErrorData {
  NSLog(@"Error loading ads: %@", adErrorData.adError.message);
  [self dismissViewControllerAnimated:TRUE completion:NULL];
}

#pragma mark - IMAStreamManagerDelegate

- (void)streamManager:(IMAStreamManager *)streamManager didReceiveAdEvent:(IMAAdEvent *)event {
  NSLog(@"StreamManager event (%@).", event.typeString);
  switch (event.type) {
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
      [self restoreFromSnapback];
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

- (void)restoreFromSnapback {
  if (self.userSeekTime && self.userSeekTime > 0.0) {
    CMTime seekCMTime = CMTimeMake(self.userSeekTime, 1);
    [self.playerViewController.player seekToTime:seekCMTime];
    self.userSeekTime = 0.0;
  }
}

- (void)streamManager:(IMAStreamManager *)streamManager didReceiveAdError:(IMAAdError *)error {
  // Fall back to playing the backup stream.
  NSLog(@"StreamManager error: %@", error.message);
  [self dismissViewControllerAnimated:TRUE completion:NULL];
}

#pragma mark - AVPlayerViewControllerDelegate

- (CMTime)playerViewController:(AVPlayerViewController *)playerViewController
    timeToSeekAfterUserNavigatedFromTime:(CMTime)oldTime
                                  toTime:(CMTime)targetTime {
  if (self.isAdBreakActive) {
    // Disable seeking during ad breaks.
    return oldTime;
  }
  if (self.streamManager) {
    CGFloat targetSeconds = CMTimeGetSeconds(targetTime);
    IMACuepoint *prevCuepoint = [self.streamManager previousCuepointForStreamTime:targetSeconds];
    if (prevCuepoint && ![prevCuepoint isPlayed]) {
      CGFloat oldSeconds = CMTimeGetSeconds(oldTime);
      if (oldSeconds < prevCuepoint.startTime) {
        self.userSeekTime = targetSeconds;
        return CMTimeMakeWithSeconds(prevCuepoint.startTime, 1);
      }
    }
  }
  return targetTime;
}

#pragma mark - IMAAVPlayerVideoDisplayDelegate

- (void)playerVideoDisplay:(IMAAVPlayerVideoDisplay *)playerVideoDisplay
         didLoadPlayerItem:(AVPlayerItem *)playerItem {
  if ([self.stream isKindOfClass:[VODStream class]]) {
    VODStream *vodStream = (VODStream *)self.stream;
    if (vodStream.bookmark && vodStream.bookmark > 0) {
      CGFloat contentTime = vodStream.bookmark;
      CGFloat streamTime = [self.streamManager streamTimeForContentTime:contentTime];
      NSLog(@"loading bookmark: %lf", contentTime);
      [self.playerViewController.player seekToTime:CMTimeMakeWithSeconds(streamTime, 1)];
    }
  }
}

@end
