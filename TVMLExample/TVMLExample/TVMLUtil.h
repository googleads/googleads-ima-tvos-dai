@import JavaScriptCore;

@interface TVMLUtil : NSObject

+ (void)callJSMethod:(JSValue *)method withParams:(id)params;

@end
