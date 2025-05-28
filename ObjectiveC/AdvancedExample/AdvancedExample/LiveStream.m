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

#import "LiveStream.h"

/// Instances of the LiveStream class store information and status for live streams.
@implementation LiveStream

- (instancetype)initWithName:(nonnull NSString *)name
                    assetKey:(nonnull NSString *)assetKey
                 networkCode:(nonnull NSString *)networkCode
                      APIKey:(nullable NSString *)APIKey {
  self = [[super init] initWithName:name APIKey:APIKey];
  if (self) {
    _assetKey = [assetKey copy];
    _networkCode = [networkCode copy];
  }
  return self;
}

- (instancetype)initWithName:(nonnull NSString *)name
                    assetKey:(nonnull NSString *)assetKey
                 networkCode:(nonnull NSString *)networkCode {
  return [self initWithName: name assetKey: assetKey networkCode: networkCode APIKey:nil];
}

@end
