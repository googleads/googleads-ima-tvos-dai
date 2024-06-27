// Copyright 2024 Google LLC. All rights reserved.
//
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use this
// file except in compliance with the License. You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
// ANY KIND, either express or implied. See the License for the specific language governing
// permissions and limitations under the License.

import AVFoundation
import GoogleInteractiveMediaAds
import UIKit

class ViewController:
  UIViewController,
  IMAAdsLoaderDelegate,
  IMAStreamManagerDelegate,
  AVPlayerViewControllerDelegate
{
  enum StreamType { case liveStream, vodStream }

  /// Video Stitcher stream request type. Either `StreamType.liveStream` or `StreamType.vodStream`.
  static let requestType = StreamType.liveStream

  /// The live stream event ID associated with this stream in your Google Cloud project.
  static let liveStreamEventID = ""
  /// The custom asset key associated with this stream in your Google Cloud project.
  static let customAssetKey = ""

  /// The VOD config ID associated with this stream in your Google Cloud project.
  static let vodConfigID = ""

  /// The network code of the Google Cloud account containing the Video Stitcher API project.
  static let networkCode = ""
  /// The project number associated with your Video Stitcher API project.
  static let projectNumber = ""
  /// The Google Cloud region where your Video Stitcher API project is located.
  static let location = ""
  /// A recently generated OAuth Token for a Google Cloud service worker account with the Video
  /// Stitcher API enabled.
  static let oAuthToken = ""

  /// Backup content URL
  static let backupStreamURLString = """
    http://googleimadev-vh.akamaihd.net/i/big_buck_bunny/\
    bbb-,480p,720p,1080p,.mov.csmil/master.m3u8
    """

  var adsLoader: IMAAdsLoader?
  var videoDisplay: IMAAVPlayerVideoDisplay!
  var adDisplayContainer: IMAAdDisplayContainer?
  var adContainerView: UIView?
  private var streamManager: IMAStreamManager?
  private var contentPlayhead: IMAAVPlayerContentPlayhead?
  private var playerViewController: AVPlayerViewController!
  private var adBreakActive = false

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = UIColor.black

    setupAdsLoader()
    setupPlayer()
    setupAdContainer()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    requestStream()
  }

  func setupAdsLoader() {
    let adsLoader = IMAAdsLoader(settings: nil)
    adsLoader.delegate = self
    self.adsLoader = adsLoader
  }

  func setupPlayer() {
    let player = AVPlayer()
    let playerViewController = AVPlayerViewController()
    playerViewController.delegate = self
    playerViewController.player = player

    // Set up our content playhead and contentComplete callback.
    contentPlayhead = IMAAVPlayerContentPlayhead(avPlayer: player)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(ViewController.contentDidFinishPlaying(_:)),
      name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
      object: player.currentItem)

    self.addChild(playerViewController)
    playerViewController.view.frame = self.view.bounds
    self.view.insertSubview(playerViewController.view, at: 0)
    playerViewController.didMove(toParent: self)
    self.playerViewController = playerViewController
  }

  func setupAdContainer() {
    // Attach the ad container to the view hierarchy on top of the player.
    let adContainerView = UIView()
    self.view.addSubview(adContainerView)
    adContainerView.frame = self.view.bounds
    // Keep hidden initially, until an ad break.
    adContainerView.isHidden = true
    self.adContainerView = adContainerView
  }

  func requestStream() {
    guard let playerViewController = self.playerViewController else { return }
    guard let adContainerView = self.adContainerView else { return }
    guard let adsLoader = self.adsLoader else { return }

    self.videoDisplay = IMAAVPlayerVideoDisplay(avPlayer: playerViewController.player!)
    adDisplayContainer = IMAAdDisplayContainer(
      adContainer: adContainerView, viewController: self)
    let streamRequest: IMAStreamRequest
    if ViewController.requestType == StreamType.liveStream {
      // Create a Livestream request.
      streamRequest = IMAVideoStitcherLiveStreamRequest(
        liveStreamEventID: ViewController.liveStreamEventID,
        region: ViewController.location,
        projectNumber: ViewController.projectNumber,
        oAuthToken: ViewController.oAuthToken,
        networkCode: ViewController.networkCode,
        customAssetKey: ViewController.customAssetKey,
        adDisplayContainer: adDisplayContainer!,
        videoDisplay: self.videoDisplay,
        userContext: nil,
        videoStitcherSessionOptions: nil)
    } else {
      // Create a VOD stream request.
      streamRequest = IMAVideoStitcherVODStreamRequest(
        vodConfigID: ViewController.vodConfigID,
        region: ViewController.location,
        projectNumber: ViewController.projectNumber,
        oAuthToken: ViewController.oAuthToken,
        networkCode: ViewController.networkCode,
        adDisplayContainer: adDisplayContainer!,
        videoDisplay: self.videoDisplay,
        userContext: nil,
        videoStitcherSessionOptions: nil)
    }
    adsLoader.requestStream(with: streamRequest)
  }

  @objc func contentDidFinishPlaying(_ notification: Notification) {
    guard let adsLoader = self.adsLoader else { return }
    adsLoader.contentComplete()
  }

  func startMediaSession() {
    try? AVAudioSession.sharedInstance().setActive(true, options: [])
    try? AVAudioSession.sharedInstance().setCategory(.playback)
  }

  // MARK: - UIFocusEnvironment

  override var preferredFocusEnvironments: [UIFocusEnvironment] {
    if adBreakActive, let adFocusEnvironment = adDisplayContainer?.focusEnvironment {
      // Send focus to the ad display container during an ad break.
      return [adFocusEnvironment]
    } else {
      // Send focus to the content player otherwise.
      return [playerViewController]
    }
  }

  // MARK: - IMAAdsLoaderDelegate

  func adsLoader(_ loader: IMAAdsLoader, adsLoadedWith adsLoadedData: IMAAdsLoadedData) {
    let streamManager = adsLoadedData.streamManager!
    streamManager.delegate = self
    streamManager.initialize(with: nil)
    self.streamManager = streamManager
  }

  func adsLoader(_ loader: IMAAdsLoader, failedWith adErrorData: IMAAdLoadingErrorData) {
    print("Error loading ads: \(String(describing: adErrorData.adError.message))")
    let streamUrl = URL(string: ViewController.backupStreamURLString)
    self.videoDisplay.loadStream(streamUrl!, withSubtitles: [])
    self.videoDisplay.play()
    playerViewController.player?.play()
  }

  // MARK: - IMAStreamManagerDelegate
  func streamManager(_ streamManager: IMAStreamManager, didReceive event: IMAAdEvent) {
    print("StreamManager event \(event.typeString).")
    switch event.type {
    case IMAAdEventType.STREAM_STARTED:
      self.startMediaSession()
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
      if let adContainerView = self.adContainerView {
        adContainerView.isHidden = false
      }
      // Trigger an update to send focus to the ad display container.
      adBreakActive = true
      setNeedsFocusUpdate()
      break
    case IMAAdEventType.AD_BREAK_ENDED:
      if let adContainerView = self.adContainerView {
        adContainerView.isHidden = true
      }
      // Trigger an update to send focus to the content player.
      adBreakActive = false
      setNeedsFocusUpdate()
      break
    case IMAAdEventType.ICON_FALLBACK_IMAGE_CLOSED:
      // Resume playback after the user has closed the dialog.
      self.videoDisplay.play()
      break
    default:
      break
    }
  }

  func streamManager(_ streamManager: IMAStreamManager, didReceive error: IMAAdError) {
    print("StreamManager error: \(error.message ?? "Unknown Error")")
  }

  // MARK: - AVPlayerViewControllerDelegate
  func playerViewController(
    _ playerViewController: AVPlayerViewController,
    timeToSeekAfterUserNavigatedFrom oldTime: CMTime,
    to targetTime: CMTime
  ) -> CMTime {
    if adBreakActive {
      return oldTime
    }
    return targetTime
  }
}
