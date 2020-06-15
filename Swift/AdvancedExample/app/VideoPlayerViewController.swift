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
import AVFoundation
import GoogleInteractiveMediaAds
import UIKit

/// The video player view controller will control playback of a stream selected in the main
/// view controller.
class VideoPlayerViewController:
  UIViewController,
  IMAAdsLoaderDelegate,
  IMAStreamManagerDelegate,
  AVPlayerViewControllerDelegate,
  IMAAVPlayerVideoDisplayDelegate
{
  public var stream: Stream?
  private var adsLoader: IMAAdsLoader?
  private var adDisplayContainer: IMAAdDisplayContainer?
  private var adContainerView: UIView?
  private var streamManager: IMAStreamManager?
  private var contentPlayhead: IMAAVPlayerContentPlayhead?
  private var playerViewController: AVPlayerViewController?
  private var userSeekTime = 0.0
  private var adBreakActive = false

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = .black

    setupAdsLoader()
    setupPlayer()
    setupAdContainer()

  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    requestStream()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    playerViewController!.player?.pause()
    saveBookmark()
    playerViewController!.player?.replaceCurrentItem(with: nil)
  }

  func saveBookmark() {
    if let vodStream = stream as? VODStream {
      let streamTime = CMTimeGetSeconds(self.playerViewController!.player!.currentTime())
      let contentTime = self.streamManager!.contentTime(forStreamTime: streamTime)
      vodStream.bookmark = contentTime
      print("saving bookmark: \(contentTime)")
    }
  }

  func setupAdsLoader() {
    adsLoader = IMAAdsLoader(settings: nil)
    adsLoader!.delegate = self
  }

  func setupPlayer() {
    let player = AVPlayer()
    playerViewController = AVPlayerViewController()
    playerViewController!.delegate = self
    playerViewController!.player = player

    // Set up our content playhead and contentComplete callback.
    contentPlayhead = IMAAVPlayerContentPlayhead(avPlayer: player)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(VideoPlayerViewController.contentDidFinishPlaying(_:)),
      name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
      object: player.currentItem)

    self.addChild(playerViewController!)
    playerViewController!.view.frame = self.view.bounds
    self.view.insertSubview(playerViewController!.view, at: 0)
    playerViewController!.didMove(toParent: self)
  }

  func setupAdContainer() {
    // Attach the ad container to the view hierarchy on top of the player.
    adContainerView = UIView()
    self.view.addSubview(self.adContainerView!)
    self.adContainerView!.frame = self.view.bounds
    // Keep hidden initially, until an ad break.
    self.adContainerView!.isHidden = true
  }

  func requestStream() {
    let videoDisplay = IMAAVPlayerVideoDisplay(avPlayer: self.playerViewController!.player)
    videoDisplay!.playerVideoDisplayDelegate = self
    adDisplayContainer = IMAAdDisplayContainer(
      adContainer: self.adContainerView!, viewController: self)
    let request: IMAStreamRequest
    if let liveStream = self.stream as? LiveStream {
      request = IMALiveStreamRequest(
        assetKey: liveStream.assetKey,
        adDisplayContainer: adDisplayContainer,
        videoDisplay: videoDisplay)
      self.adsLoader!.requestStream(with: request)
    } else if let vodStream = self.stream as? VODStream {
      request = IMAVODStreamRequest(
        contentSourceID: vodStream.cmsID,
        videoID: vodStream.videoID,
        adDisplayContainer: adDisplayContainer,
        videoDisplay: videoDisplay)
      self.adsLoader!.requestStream(with: request)
    } else {
      assertionFailure("Unknown stream type selected")
      self.dismiss(animated: false, completion: nil)
    }

  }

  @objc func contentDidFinishPlaying(_ notification: Notification) {
    adsLoader!.contentComplete()
    self.dismiss(animated: false, completion: nil)
  }

  // MARK: - UIFocusEnvironment

  override var preferredFocusEnvironments: [UIFocusEnvironment] {
    if adBreakActive {
      // Send focus to the ad display container during an ad break.
      return [adDisplayContainer!.focusEnvironment!]
    } else {
      // Send focus to the content player otherwise.
      return [playerViewController!]
    }
  }

  // MARK: - IMAAdsLoaderDelegate
  func adsLoader(_ loader: IMAAdsLoader!, adsLoadedWith adsLoadedData: IMAAdsLoadedData!) {
    // Grab the instance of the IMAAdsManager and set ourselves as the delegate.
    streamManager = adsLoadedData.streamManager
    streamManager!.delegate = self
    streamManager!.initialize(with: nil)
  }

  func adsLoader(_ loader: IMAAdsLoader!, failedWith adErrorData: IMAAdLoadingErrorData!) {
    print("Error loading ads: \(adErrorData.adError.message ?? "Unknown Error")")
    self.dismiss(animated: false, completion: nil)
  }

  // MARK: - IMAStreamManagerDelegate
  func streamManager(_ streamManager: IMAStreamManager!, didReceive event: IMAAdEvent!) {
    print("StreamManager event \(event.typeString!).")
    switch event.type {
    case IMAAdEventType.STARTED:
      // Log extended data.
      let extendedAdPodInfo = String(
        format: "Showing ad %zd/%zd, bumper: %@, title: %@, "
          + "description: %@, contentType:%@, pod index: %zd, "
          + "time offset: %lf, max duration: %lf.",
        event.ad.adPodInfo.adPosition,
        event.ad.adPodInfo.totalAds,
        event.ad.adPodInfo.isBumper ? "YES" : "NO",
        event.ad.adTitle,
        event.ad.adDescription,
        event.ad.contentType,
        event.ad.adPodInfo.podIndex,
        event.ad.adPodInfo.timeOffset,
        event.ad.adPodInfo.maxDuration)

      print("\(extendedAdPodInfo)")
      break
    case IMAAdEventType.AD_BREAK_STARTED:
      // Prevent user seek through when an ad starts and show the ad controls.
      self.playerViewController!.requiresLinearPlayback = true
      self.adContainerView!.isHidden = false
      // Trigger an update to send focus to the ad display container.
      adBreakActive = true
      setNeedsFocusUpdate()
      break
    case IMAAdEventType.AD_BREAK_ENDED:
      // Allow user seek through after an ad ends and hide the ad controls.
      restoreFromSnapback()
      self.playerViewController!.requiresLinearPlayback = false
      self.adContainerView!.isHidden = true
      // Trigger an update to send focus to the content player.
      adBreakActive = false
      setNeedsFocusUpdate()
      break
    default:
      break
    }
  }

  func restoreFromSnapback() {
    if userSeekTime > 0.0 {
      let seekCMTime = CMTimeMakeWithSeconds(userSeekTime, preferredTimescale: 1)
      playerViewController!.player!.seek(
        to: seekCMTime,
        toleranceBefore: CMTime.zero,
        toleranceAfter: CMTime.zero)
      self.userSeekTime = 0.0
    }
  }

  func streamManager(_ streamManager: IMAStreamManager!, didReceive error: IMAAdError!) {
    print("StreamManager error: \(error.message ?? "Unknown Error")")
    self.dismiss(animated: false, completion: nil)
  }

  // MARK: - AVPlayerViewControllerDelegate
  func playerViewController(
    _ playerViewController: AVPlayerViewController,
    timeToSeekAfterUserNavigatedFrom oldTime: CMTime,
    to targetTime: CMTime
  ) -> CMTime {
    if let streamManager = self.streamManager {
      // perform snapback if user scrubs ahead of ad break
      let targetSeconds = CMTimeGetSeconds(targetTime)
      let prevCuepoint = streamManager.previousCuepoint(forStreamTime: targetSeconds)
      if let cuepoint = prevCuepoint {
        if !cuepoint.isPlayed {
          let oldSeconds = CMTimeGetSeconds(oldTime)
          if oldSeconds < cuepoint.startTime {
            self.userSeekTime = targetSeconds
            return CMTimeMakeWithSeconds(cuepoint.startTime, preferredTimescale: 1)
          }
        }
      }
    }
    return targetTime
  }

  // MARK: - IMAAVPlayerVideoDisplayDelegate
  func playerVideoDisplay(
    _ playerVideoDisplay: IMAAVPlayerVideoDisplay!,
    didLoad playerItem: AVPlayerItem!
  ) {
    // load bookmark, if it exists (and we aren't playing a live stream)
    if let vodStream = stream as? VODStream {
      if vodStream.bookmark != 0 {
        let contentTime = vodStream.bookmark
        let streamTime = streamManager!.streamTime(forContentTime: contentTime)
        print("loading bookmark: \(contentTime)")
        let seekTime = CMTimeMakeWithSeconds(streamTime, preferredTimescale: 1)
        self.playerViewController!.player!.seek(to: seekTime)
      }
    }
  }
}
