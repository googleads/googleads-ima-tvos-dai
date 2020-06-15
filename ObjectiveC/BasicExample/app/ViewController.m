/**
 * Copyright 2019 Google LLC
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

// Live stream asset key, VOD content source and video IDs, and backup content URL.
static NSString *const kAssetKey = @"sN_IYUG8STe1ZzhIIE_ksA";
static NSString *const kContentSourceID = @"19463";
static NSString *const kVideoID = @"googleio-highlights";
static NSString *const kBackupStreamURLString =
    @"http://googleimadev-vh.akamaihd.net/i/big_buck_bunny/bbb-,480p,720p,1080p,.mov.csmil/"
    @"master.m3u8";

@interface ViewController () <IMAAdsLoaderDelegate, IMAStreamManagerDelegate>
@property(nonatomic) IMAAdsLoader *adsLoader;
@property(nonatomic) UIView *adContainerView;
@property(nonatomic) IMAStreamManager *streamManager;
@property(nonatomic) AVPlayerViewController *playerViewController;
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
  IMAAVPlayerVideoDisplay *videoDisplay =
      [[IMAAVPlayerVideoDisplay alloc] initWithAVPlayer:self.playerViewController.player];
  IMAAdDisplayContainer *adDisplayContainer =
      [[IMAAdDisplayContainer alloc] initWithAdContainer:self.adContainerView viewController:self];
  IMALiveStreamRequest *request = [[IMALiveStreamRequest alloc] initWithAssetKey:kAssetKey
                                                              adDisplayContainer:adDisplayContainer
                                                                    videoDisplay:videoDisplay];
  // VOD request. Comment out the IMALiveStreamRequest above and uncomment this IMAVODStreamRequest
  // to switch from a livestream to a VOD stream.
  // IMAVODStreamRequest *request =
  //     [[IMAVODStreamRequest alloc] initWithContentSourceID:kContentSourceID
  //                                                  videoID:kVideoID
  //                                       adDisplayContainer:adDisplayContainer
  //                                             videoDisplay:videoDisplay];
  [self.adsLoader requestStreamWithRequest:request];
}

- (void)playBackupStream {
  NSURL *backupStreamURL = [NSURL URLWithString:kBackupStreamURLString];
  AVPlayerItem *backupStreamItem = [AVPlayerItem playerItemWithURL:backupStreamURL];
  [self.playerViewController.player replaceCurrentItemWithPlayerItem:backupStreamItem];
  [self.playerViewController.player play];
}

#pragma mark - IMAAdsLoaderDelegate

- (void)adsLoader:(IMAAdsLoader *)loader adsLoadedWithData:(IMAAdsLoadedData *)adsLoadedData {
  // Initialize and listen to stream manager's events.
  self.streamManager = adsLoadedData.streamManager;
  self.streamManager.delegate = self;
  [self.streamManager initializeWithAdsRenderingSettings:nil];
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
      // Prevent user seek through when an ad starts and show the ad controls.
      self.playerViewController.requiresLinearPlayback = YES;
      self.adContainerView.hidden = NO;
      break;
    }
    case kIMAAdEvent_AD_BREAK_ENDED: {
      // Allow user seek through after an ad ends and hide the ad controls.
      self.playerViewController.requiresLinearPlayback = NO;
      self.adContainerView.hidden = YES;
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

@end
