#import "Ads.h"

#import "IMATVMLCuepoint.h"
#import "TVMLUtil.h"

@interface Ads () <IMAStreamManagerDelegate>

@property(nonatomic, strong) IMATVMLPlayerVideoDisplay *videoDisplay;
@property(nonatomic, strong) IMAStreamManager *streamManager;

@end

@implementation Ads

@synthesize JSAdBreakStarted;
@synthesize JSAdBreakEnded;
@synthesize JSCuepointsDidChange;

- (id)initWithVideoDisplay:(IMATVMLPlayerVideoDisplay *)videoDisplay {
  self.videoDisplay = videoDisplay;
  return self;
}

- (void)requestLiveStreamWithAssetKey:(NSString *)assetKey {
  [self initStreamManager];
  IMALiveStreamRequest *streamRequest = [[IMALiveStreamRequest alloc] initWithAssetKey:assetKey];
  [self.streamManager requestStream:streamRequest];
}

- (void)requestVODStreamWithContentSourceID:(NSString *)contentSourceID
                                    videoID:(NSString *)videoID {
  [self initStreamManager];
  IMAVODStreamRequest *streamRequest =
      [[IMAVODStreamRequest alloc] initWithContentSourceID:contentSourceID videoID:videoID];
  [self.streamManager requestStream:streamRequest];
}

- (void)initStreamManager {
  self.streamManager = [[IMAStreamManager alloc] initWithVideoDisplay:self.videoDisplay];
  self.streamManager.delegate = self;
}

- (IMATVMLCuepoint *)getPreviousCuepointForStreamTime:(NSTimeInterval)streamTime {
  if (self.streamManager) {
    IMACuepoint *cuepoint = [self.streamManager previousCuepointForStreamTime:streamTime];
    return [[IMATVMLCuepoint alloc] initWithCuepoint:cuepoint];
  }
  return nil;
}

#pragma mark - IMAStreamManagerDelegate methods

- (void)streamManager:(IMAStreamManager *)streamManager didReceiveError:(NSError *)error {
  NSLog(@"Error: %@", error.localizedDescription);
}

- (void)streamManager:(IMAStreamManager *)streamManager didInitializeStream:(NSString *)streamID {
  NSLog(@"Stream initialized with streamID: %@", streamID);
}

- (void)streamManager:(IMAStreamManager *)streamManager
      adBreakDidStart:(IMAAdBreakInfo *)adBreakInfo {
  NSLog(@"Stream manager event (ad break start)");
  [TVMLUtil callJSMethod:self.JSAdBreakStarted withParams:nil];
}

- (void)streamManager:(IMAStreamManager *)streamManager
        adBreakDidEnd:(IMAAdBreakInfo *)adBreakInfo {
  NSLog(@"Stream manager event (ad break complete)");
  [TVMLUtil callJSMethod:self.JSAdBreakEnded withParams:nil];
}

- (void)streamManager:(IMAStreamManager *)streamManager
    didUpdateCuepoints:(NSArray<IMACuepoint *> *)cuepoints {
  NSLog(@"Did update cuepoints.");
  NSMutableArray<IMATVMLCuepoint *> *tvmlCuepoints = [NSMutableArray array];
  for (IMACuepoint *cuepoint in cuepoints) {
    [tvmlCuepoints addObject:[[IMATVMLCuepoint alloc] initWithCuepoint:cuepoint]];
  }
  [TVMLUtil callJSMethod:self.JSCuepointsDidChange withParams:tvmlCuepoints];
}

@end
