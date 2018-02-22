@import JavaScriptCore;
@import InteractiveMediaAds;

@protocol IMATVMLPlayerVideoDisplayExport<JSExport>

@property(nonatomic, strong) JSValue *JSUrlLoader;

- (void)onVideoDisplayReady;

- (void)onTimeDidChange:(NSInteger)currentTime;

- (void)reportTimedMetadataForKey:(NSString *)key value:(NSString *)value;

- (void)onPlaybackError:(NSString *)errorString;

@end

@interface IMATVMLPlayerVideoDisplay : NSObject<IMATVMLPlayerVideoDisplayExport, IMAVideoDisplay>

@end
