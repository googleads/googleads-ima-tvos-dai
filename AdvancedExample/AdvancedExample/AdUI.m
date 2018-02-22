#import "AdUI.h"

#import <Foundation/Foundation.h>

@interface AdUI ()

@property(nonatomic, assign) NSInteger adPosition;
@property(nonatomic, assign) NSInteger totalAds;
@property(nonatomic, assign) NSTimeInterval remainingTime;
@property(nonatomic, strong) UILabel *adInfoLabel;

@end

@implementation AdUI

- (instancetype)init {
  self = [super init];
  if (self) {
    _adInfoLabel = [[UILabel alloc] init];
    [self addSubview:_adInfoLabel];
  }
  return self;
}

- (void)updateCountdownTimer:(NSTimeInterval)time {
  self.remainingTime = time;
  self.adInfoLabel.text = [self adInfo];
}

- (void)updateAdPosition:(NSInteger)adPosition totalAds:(NSInteger)totalAds {
  self.adPosition = adPosition;
  self.totalAds = totalAds;
  self.adInfoLabel.text = [self adInfo];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  self.adInfoLabel.text = @"Ad";
  self.adInfoLabel.textColor = [UIColor grayColor];
  self.adInfoLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:36];
  [self.adInfoLabel sizeToFit];
  self.adInfoLabel.frame =
  self.adInfoLabel.frame = CGRectMake(
      0, (self.bounds.size.height - self.adInfoLabel.bounds.size.height),
      self.bounds.size.width, self.adInfoLabel.bounds.size.height);
}

- (NSString *)adInfo {
  NSString *adString = @"Ad";
  if (self.adPosition && self.totalAds) {
    adString = [adString stringByAppendingString:
       [[NSString alloc] initWithFormat:@"Ad (%ld of %ld)", self.adPosition, self.totalAds]];
    if (self.remainingTime) {
      adString = [adString stringByAppendingString:
          [[NSString alloc] initWithFormat:@": %@",
             [self stringFromTimeInterval:self.remainingTime]]];
    }
  }
  return adString;
}

- (NSString *)stringFromTimeInterval:(NSTimeInterval)interval {
  NSInteger timeInterval = (NSInteger)interval;
  NSInteger seconds = timeInterval % 60;
  NSInteger minutes = (timeInterval / 60) % 60;
  return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
}

@end