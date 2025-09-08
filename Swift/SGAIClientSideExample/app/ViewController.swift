/**
 * Copyright 2025 Google LLC
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
import AVFoundation
import GoogleInteractiveMediaAds
import UIKit

class ViewController:
  UIViewController,
  IMAAdsLoaderDelegate,
  IMAStreamManagerDelegate,
  AVPlayerViewControllerDelegate
{

  private enum StreamParameters {
    static let contentStream =
      "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"

    // Find your [Google Ad Manager network code](https://support.google.com/admanager/answer/7674889)
    // or use the test network code and custom asset key with the DAI type "Pod serving manifest"
    // from [DAI sample streams](https://developers.google.com/ad-manager/dynamic-ad-insertion/streams#pod_serving_dai).

    /// Google Ad Manager network code.
    static let networkCode = "21775744923"

    /// Google DAI livestream custom asset key.
    static let customAssetKey = "sgai-hls-live"

    // Set your ad break duration.
    static let adBreakDurationMs = 10000
  }

  /// The view to display the ad UI elements: count down, skip button, etc.
  /// It is hidden when the stream starts playing.
  private var adUIView: UIView!

  /// The reference of your ad UI view for the IMA SDK to create the ad's user interface elements.
  private var adDisplayContainer: IMAAdDisplayContainer!

  /// The AVPlayer instance that plays the content and the ads.
  private var player: AVPlayer!

  /// The reference of your video player for the IMA SDK to play and monitor the ad breaks.
  private var videoDisplay: IMAAVPlayerVideoDisplay!

  /// The entry point of the IMA SDK to make stream requests to Google Ad Manager.
  private var adsLoader: IMAAdsLoader!

  /// The reference of the ad stream manager, set when the ad stream is loaded.
  /// The IMA SDK requires a strong reference to the stream manager for the entire duration of
  /// the ad break.
  private var streamManager: IMAStreamManager?

  /// The ad stream session ID, set when the ad stream is loaded.
  private var adStreamSessionId: String?

  private var playerViewController: AVPlayerViewController!
  private var userSeekTime = 0.0
  private var adBreakActive = false

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  override func viewDidLoad() {

    // Initialize the IMA SDK.
    let adLoaderSettings = IMASettings()
    // Uncomment the next line for ad UI localization.
    // adLoaderSettings.language = "es"
    adLoaderSettings.enableDebugMode = true
    adsLoader = IMAAdsLoader(settings: adLoaderSettings)

    // Set up the video player and the container view.
    player = AVPlayer()
    let playerViewController = AVPlayerViewController()
    playerViewController.player = player
    playerViewController.didMove(toParent: self)

    // Create an object to monitor the stream playback.
    videoDisplay = IMAAVPlayerVideoDisplay(avPlayer: player)

    adUIView = UIView()

    super.viewDidLoad()

    // Create a container object for ad UI elements.
    // See [example in video ads](https://support.google.com/admanager/answer/2695279#zippy=%2Cexample-in-video-ads)
    adDisplayContainer = IMAAdDisplayContainer(
      adContainer: adUIView, viewController: self)

    // Set the background color of the view to black.
    self.view.backgroundColor = UIColor.black
    self.view.insertSubview(playerViewController.view, at: 0)
    playerViewController.view.frame = self.view.bounds
    playerViewController.delegate = self
    self.playerViewController = playerViewController
    self.addChild(playerViewController)

    self.view.addSubview(adUIView)
    adUIView.frame = self.view.bounds
    // Keep hidden initially, until an ad break.
    adUIView.isHidden = true

    adsLoader.delegate = self
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    loadAdStream()
    loadContentStream()
  }

  /// Loads the content stream and plays it automatically.
  private func loadContentStream() {
    guard let contentURL = URL(string: StreamParameters.contentStream) else {
      print("Failed to load content stream. The URL is invalid.")
      return
    }
    let item = AVPlayerItem(url: contentURL)
    player.replaceCurrentItem(with: item)
    player.play()
  }

  /// Makes a stream request to Google Ad Manager.
  private func loadAdStream() {
    let streamRequest = IMAPodStreamRequest(
      networkCode: StreamParameters.networkCode,
      customAssetKey: StreamParameters.customAssetKey,
      adDisplayContainer: adDisplayContainer,
      videoDisplay: videoDisplay,
      pictureInPictureProxy: nil,
      userContext: nil)

    // Register a streaming session on Google Ad Manager DAI servers.
    adsLoader.requestStream(with: streamRequest)
  }

  /// Schedules ad insertion shortly before ad break starts.
  private func scheduleAdInsertion() {
    guard let streamID = self.adStreamSessionId else {
      print("The ad stream ID is not set. Skipping all ad breaks of the current stream session.")
      return
    }

    let currentSeconds = Int(Date().timeIntervalSince1970)
    var secondsToAdBreakStart = 60 - currentSeconds % 60
    // If there is less than 30 seconds remaining in the current minute,
    // schedule the ad insertion for the next minute instead.
    if secondsToAdBreakStart < 30 {
      secondsToAdBreakStart += 60
    }

    guard let primaryPlayerCurrentItem = player.currentItem else {
      print(
        "Failed to get the player item of the content stream. Skipping an ad break in \(secondsToAdBreakStart) seconds."
      )
      return
    }

    let adBreakStartTime = CMTime(
      seconds: primaryPlayerCurrentItem.currentTime().seconds
        + Double(secondsToAdBreakStart), preferredTimescale: 1)

    // Create an identifier to construct the ad pod request for the next ad break.
    let adPodIdentifier = generatePodIdentifier(from: currentSeconds)

    // Construct the ad pod request URL for the next ad break.
    guard
      let adPodManifestUrl = URL(
        string:
          "https://dai.google.com/linear/pods/v1/hls/network/\(StreamParameters.networkCode)/custom_asset/\(StreamParameters.customAssetKey)/\(adPodIdentifier).m3u8?stream_id=\(streamID)&pd=\(StreamParameters.adBreakDurationMs)"
      )
    else {
      // If URL creation fails, verify that StreamParameters and streamID are not empty.
      print("Failed to construct ad pod manifest URL. Skipping ad break.")
      return
    }

    let interstitialEvent = AVPlayerInterstitialEvent(
      primaryItem: primaryPlayerCurrentItem,
      identifier: adPodIdentifier,
      time: adBreakStartTime,
      templateItems: [AVPlayerItem(url: adPodManifestUrl)],
      restrictions: [],
      resumptionOffset: .zero)
    let interstitialEventController = AVPlayerInterstitialEventController(primaryPlayer: player)
    interstitialEventController.events = [interstitialEvent]
    print(
      "Ad break scheduled to start in \(secondsToAdBreakStart) seconds. Ad break manifest URL: \(adPodManifestUrl)."
    )
  }

  /// Generates a pod identifier based on the current time.
  ///
  /// See [HLS pod manifest parameters](https://developers.google.com/ad-manager/dynamic-ad-insertion/api/pod-serving/reference/live#path_parameters_3).
  ///
  /// - Returns: The pod identifier in either the format of "pod/{integer}" or
  ///   "ad_break_id/{string}".
  private func generatePodIdentifier(from currentSeconds: Int) -> String {
    let minute = Int(currentSeconds / 60) + 1
    return "ad_break_id/mid-roll-\(minute)"
  }

  // MARK: - IMAAdsLoaderDelegate
  func adsLoader(_ loader: IMAAdsLoader, adsLoadedWith adsLoadedData: IMAAdsLoadedData) {
    guard let streamManager = adsLoadedData.streamManager else {
      // Report a bug on [IMA SDK forum](https://groups.google.com/g/ima-sdk).
      print("Failed to retrieve stream manager from ads loaded data.")
      return
    }
    // Save the stream manager to handle ad events of the stream session.
    self.streamManager = streamManager
    streamManager.delegate = self
    let adRenderingSettings = IMAAdsRenderingSettings()
    // Uncomment the next line to enable the current view controller
    // to get notified of ad clicks.
    // adRenderingSettings.linkOpenerDelegate = self
    // Initialize the stream manager to create ad UI elements.
    streamManager.initialize(with: adRenderingSettings)

    guard let streamId = streamManager.streamId else {
      // Report a bug on [IMA SDK forum](https://groups.google.com/g/ima-sdk).
      print("Failed to retrieve stream ID from stream manager.")
      return
    }
    // Save the ad stream session ID to construct ad pod requests.
    adStreamSessionId = streamId

    // At this point the content stream playback started and the DAI stream
    // session has also started, you can observe the content stream's timed
    // metadata for ad markers to schedule ad insertion. Alternatively, you
    // can schedule ad insertion using other data sources or events.
    //
    // For example, this app schedules an ad break within 2 minutes after
    // the content stream playback starts.
    scheduleAdInsertion()
  }

  func adsLoader(_ loader: IMAAdsLoader, failedWith adErrorData: IMAAdLoadingErrorData) {
    guard let errorMessage = adErrorData.adError.message else {
      print("Stream registration failed with unknown error.")
      return
    }
    print("Stream registration failed with error: \(errorMessage)")
  }

  // MARK: - IMAStreamManagerDelegate
  func streamManager(_ streamManager: IMAStreamManager, didReceive event: IMAAdEvent) {
    switch event.type {
    case IMAAdEventType.STARTED:
      // Log extended data.
      if let ad = event.ad {
        let extendedAdPodInfo = String(
          format: "Showing ad %zd/%zd, bumper: %@, title: %@, "
            + "description: %@, contentType:%@, pod index: %zd, "
            + "time offset: %lf, max duration: %lf.",
          ad.adPodInfo.adPosition,
          ad.adPodInfo.totalAds,
          ad.adPodInfo.isBumper ? "YES" : "NO",
          ad.adTitle,
          ad.adDescription,
          ad.contentType,
          ad.adPodInfo.podIndex,
          ad.adPodInfo.timeOffset,
          ad.adPodInfo.maxDuration)

        print("\(extendedAdPodInfo)")
      }
      break
    case IMAAdEventType.AD_BREAK_STARTED:
      print("Ad break started.")
      break
    case IMAAdEventType.AD_BREAK_ENDED:
      print("Ad break ended.")
      break
    case IMAAdEventType.AD_PERIOD_STARTED:
      print("Ad period started.")
      break
    case IMAAdEventType.AD_PERIOD_ENDED:
      print("Ad period ended.")
      break
    default:
      break
    }
  }

  func streamManager(_ streamManager: IMAStreamManager, didReceive error: IMAAdError) {
    guard let errorMessage = error.message else {
      print("Ad stream failed to load with unknown error.")
      return
    }
    print("Ad stream failed to load with error: \(errorMessage)")
  }
}
