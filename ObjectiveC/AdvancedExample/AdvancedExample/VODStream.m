/**
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *  https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "VODStream.h"

/// Instances of the VODStream class store information and status for Video On Demand streams.
/// Note that the bookmark property will be altered during playback, to store progress.
@implementation VODStream

- (instancetype)initWithName:(nonnull NSString *)name
                   contentID:(nonnull NSString *)contentID
                     videoID:(nonnull NSString *)videoID
                      APIKey:(nullable NSString *)APIKey {
  self = [[super init] initWithName:name APIKey:APIKey];
  if (self) {
    _contentID = [contentID copy];
    _videoID = [videoID copy];
    _bookmark = 0.0;
  }
  return self;
}

- (instancetype)initWithName:(nonnull NSString *)name
                   contentID:(nonnull NSString *)contentID
                     videoID:(nonnull NSString *)videoID {
  return [self initWithName:name contentID:contentID videoID:videoID APIKey:nil];
}

@end
