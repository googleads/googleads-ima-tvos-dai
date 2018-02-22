@import InteractiveMediaAds;
@import JavaScriptCore;

@protocol IMATVMLCuepointExport<JSExport>

@property(nonatomic, assign) NSInteger starttime;

@property(nonatomic, assign) NSInteger endtime;

@property(nonatomic, assign) NSInteger duration;

@property(nonatomic, assign) BOOL played;

@end

@interface IMATVMLCuepoint : NSObject<IMATVMLCuepointExport>

- (instancetype)initWithCuepoint:(IMACuepoint *)cuepoint;

@end
