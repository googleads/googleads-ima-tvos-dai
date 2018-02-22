/**
 *  Wrapper for a TVML Player to support the IMA SDK for tvOS.
 *  @param {Player} player A TVML Player.
 *  @param {IMATVMLPlayerVideoDisplay} videoDisplay Instance of IMATVMLPlayerVideoDisplay used to
 *      used to interface with the tvOS SDK.
 *  @constructor
 */
var IMATVMLPlayerWrapper = function(player, videoDisplay) {
  this.player = player;
  this.videoDisplay = videoDisplay;
  this.playerCuepoints = null;
  this.videoDisplay.JSUrlLoader = this.loadUrl.bind(this);
  this.player.addEventListener('timeDidChange', this.onTimeDidChange.bind(this), {interval: 1});
  this.player.addEventListener('timedMetadata', this.onTimedMetadata.bind(this), ["id3/TXXX"]);
  this.player.addEventListener('playbackError', this.onPlaybackError.bind(this));
}

/**
 *  Sets the interstitial windows for the TVML Player.
 *  @param {Array<IMATVMLCuepoint>} cuepoints Array of IMATVMLCuepoints.
 */
IMATVMLPlayerWrapper.prototype.setCuepoints = function(cuepoints) {
  this.playerCuepoints = [];
  for (var i=0; i < cuepoints.length; i++) {
    var cuepoint = cuepoints[i];
    this.playerCuepoints.push({
      starttime: cuepoint.starttime,
      duration: cuepoint.duration
    });
  }
}

/**
 *  Called by IMATVMLPlayerVideoDisplay. Loads the provided URL in the video player.
 *  @param {string} url Url to be loaded into the player.
 */
IMATVMLPlayerWrapper.prototype.loadUrl = function(url) {
  var myVideo = new MediaItem('video', url);
  if (this.playerCuepoints) {
    myVideo.interstitials = this.playerCuepoints;
  }
  this.player.playlist = new Playlist();
  this.player.playlist.push(myVideo);
  this.videoDisplay.onVideoDisplayReady();
  this.player.play();
}

/**
 *  Called when the time changes. Used to update the SDK with stream progress.
 *  @param {Event} event Event from the TVML Player with progress info.
 */
IMATVMLPlayerWrapper.prototype.onTimeDidChange = function(event) {
  this.videoDisplay.onTimeDidChange(event.time);
}

/**
 *  Called when the stream receives timed metadata.
 *  @param {Event} event Event from the TVML Player with metadata info.
 */
IMATVMLPlayerWrapper.prototype.onTimedMetadata = function(event) {
  this.videoDisplay.reportTimedMetadataForKeyValue(event.metadata.key, event.metadata.stringValue);
}

/**
 *  Called when the TVML Player encouters an error and forwards that error to the SDK.
 *  @param {Event} event Event from the TVML Player with error info.
 */
IMATVMLPlayerWrapper.prototype.onPlaybackError = function(event) {
  if (event.shouldStopDueToError) {
    this.videoDisplay.onPlaybackError(event.reason);
  }
}
