#import "IMATVMLCuepoint.h"

@implementation IMATVMLCuepoint

@synthesize starttime;
@synthesize endtime;
@synthesize duration;
@synthesize played;

- (instancetype)initWithCuepoint:(IMACuepoint *)cuepoint {
  self = [super init];
  self.starttime = cuepoint.startTime;
  self.endtime = cuepoint.endTime;
  self.duration = cuepoint.endTime - cuepoint.startTime;
  self.played = cuepoint.played;
  return self;
}

@end
