#import "TVMLUtil.h"

@implementation TVMLUtil

+ (void)callJSMethod:(JSValue *)method withParams:(id)params {
  if (params) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [method.context[@"setTimeout"] callWithArguments:@[ method, @0, params ]];
    });
  } else {
    dispatch_async(dispatch_get_main_queue(), ^{
      [method.context[@"setTimeout"] callWithArguments:@[ method, @0 ]];
    });
  }
}

@end
