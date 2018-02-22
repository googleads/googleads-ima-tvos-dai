@import JavaScriptCore;
@import InteractiveMediaAds;
@import TVMLKit;

#import "IMATVMLCuepoint.h"
#import "IMATVMLPlayerVideoDisplay.h"

@protocol AdsExport<JSExport>

@property(nonatomic, strong) JSValue *JSAdBreakStarted;

@property(nonatomic, strong) JSValue *JSAdBreakEnded;

@property(nonatomic, strong) JSValue *JSCuepointsDidChange;

- (void)requestLiveStreamWithAssetKey:(NSString *)assetKey;

- (void)requestVODStreamWithContentSourceID:(NSString *)contentSourceID videoID:(NSString *)videoID;

- (IMATVMLCuepoint *)getPreviousCuepointForStreamTime:(NSTimeInterval)streamTime;

@end

@interface Ads : NSObject<AdsExport>

- (id)initWithVideoDisplay:(IMATVMLPlayerVideoDisplay *)videoDisplay;

@end
