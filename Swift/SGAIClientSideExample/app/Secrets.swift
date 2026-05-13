// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

// Secrets provided by your Google Ad Manager account.
enum Secrets {
  // Add your Stream Create Authentication Key from Google Ad Manager.
  // See https://developers.google.com/ad-manager/dynamic-ad-insertion/api/pod-serving/live/stream-session-requests
  static let streamCreateSecret = ""

  // Add your Pod Resource Authentication Key from Google Ad Manager.
  // See https://developers.google.com/ad-manager/dynamic-ad-insertion/api/pod-serving/live/pod-manifest-requests
  static let manifestSecret = ""
}
