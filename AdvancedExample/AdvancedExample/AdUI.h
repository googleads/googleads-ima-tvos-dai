#import <UIKit/UIKit.h>

@interface AdUI : UIView

/**
 *  Updates the countdown timer in the ad UI.
 *
 *  @param time  The remaining time for the currently playing ad.
 */
- (void)updateCountdownTimer:(NSTimeInterval)time;

/**
 *  Updates the ad position and total ads in the ad UI.
 *
 *  @param adPosition   The ad position of the currently playing ad.
 *  @param totalAds     The total number of ads in the current ad break.
 */
- (void)updateAdPosition:(NSInteger)adPosition
                totalAds:(NSInteger)totalAds;

@end