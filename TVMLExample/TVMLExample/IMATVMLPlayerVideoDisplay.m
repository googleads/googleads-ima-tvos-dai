#import "IMATVMLPlayerVideoDisplay.h"
#import "TVMLUtil.h"

@interface IMATVMLPlayerVideoDisplay ()

@end

@implementation IMATVMLPlayerVideoDisplay

@synthesize delegate;
@synthesize JSUrlLoader;

- (void)onVideoDisplayReady {
  NSLog(@"Display ready");
  [self.delegate videoDisplayIsPlaybackReady:self];
}

- (void)onTimeDidChange:(NSInteger)currentTime {
  NSTimeInterval timeInterval = @(currentTime).doubleValue;
  [self.delegate videoDisplay:self didProgressToTime:timeInterval];
}

- (void)reportTimedMetadataForKey:(NSString *)key value:(NSString *)value {
  [self.delegate videoDisplay:self didReceiveTimedMetadata:@{key : value}];
}

- (void)onPlaybackError:(NSString *)errorString {
  NSLog(@"Playback error: %@", errorString);
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : errorString};
  NSError *error = [NSError errorWithDomain:@"player" code:400 userInfo:userInfo];
  [self.delegate videoDisplay:self didFailWithError:error];
}

#pragma mark - IMAVideoDisplay method

- (void)loadURL:(NSURL *)url withSubtitles:(NSArray<NSDictionary *> *)subtitles {
  [TVMLUtil callJSMethod:self.JSUrlLoader withParams:url.absoluteString];
}

@end
