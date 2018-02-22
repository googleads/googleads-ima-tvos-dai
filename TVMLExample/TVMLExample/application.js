/**
 *  Just loads IMATVMLPlayerWrapper.js and calls init.
 *  @param {Object} options Options set up in AppDelegate.m.
 */
App.onLaunch = function(options) {
  var javascriptFiles = [`${options.BASEURL}IMATVMLPlayerWrapper.js`];
  evaluateScripts(javascriptFiles, function(success) {
    if (success) {
      var myApp = new MyApp();
    }
  });
}

/**
 *  Application logic for sample TVML IMA tvOS SDK integration.
 *  @constructor
 */
MyApp = function() {
  this.checkForSnapbackOnNextSeek = true;
  this.scanStartTime = 0;
  this.inSnapback = false;
  this.snapbackEndTime = 0;
  this.player = new Player();
  this.player.addEventListener('requestSeekToTime', this.onRequestSeekToTime.bind(this));
  this.player.addEventListener('stateDidChange', this.onStateDidChange.bind(this));
  this.imaPlayerWrapper = new IMATVMLPlayerWrapper(this.player, videoDisplay);
  ads.JSAdBreakStarted = this.adBreakStarted.bind(this);
  ads.JSAdBreakEnded = this.adBreakEnded.bind(this);
  ads.JSCuepointsDidChange = this.cuepointsDidChange.bind(this);
  // Uncomment this for live stream.
  //this.liveStream = true;
  //ads.requestLiveStreamWithAssetKey(MyApp.SAMPLE_ASSET_KEY);
  // VOD stream. If you uncomment the above 2 lines for live stream, comment out these 2 lines.
  this.liveStream = false;
  ads.requestVODStreamWithContentSourceIDVideoID(MyApp.SAMPLE_CMS_ID, MyApp.SAMPLE_VIDEO_ID);
}

/**
 *  Sample live stream asset key.
 *  @const {string}
 */
MyApp.SAMPLE_ASSET_KEY = 'sN_IYUG8STe1ZzhIIE_ksA';

/**
 *  Sample VOD CMS ID.
 *  @const {string}
 */
MyApp.SAMPLE_CMS_ID = '19463';

/**
 *  Sample VOD video ID.
 *  @const {string}
 */
MyApp.SAMPLE_VIDEO_ID = 'tears-of-steel';

/**
 *  Called when an ad break starts.
 */
MyApp.prototype.adBreakStarted = function() {
  console.log('in ad break');
}

/**
 *  Called when an ad break ends. If in snapback mode, seeks to the time the user tried to get to
 *  before being sent back to the ad break that just played.
 */
MyApp.prototype.adBreakEnded = function() {
  console.log('exit ad break');
  console.log('this.inSnapback = ' + this.inSnapback);
  if (this.inSnapback) {
    this.inSnapback = false;
    this.checkForSnapbackOnNextSeek = false;
    console.log('seeking to ' + this.snapbackEndTime);
    this.player.seekToTime(this.snapbackEndTime);
  }
}

/**
 *  Called when the cuepoints for the stream change. Used to set interstitial windows on the
 *  Player's MediaItem.
 *  @param {Array<IMATVMLCuepoint> cuepoints Array of IMATVMLCuepoints.
 */
MyApp.prototype.cuepointsDidChange = function(cuepoints) {
  this.imaPlayerWrapper.setCuepoints(cuepoints);
}

/**
 *  Called when the user seeks via trick play (click and release on left or right side of remote),
 *  or when we seek programmatically via player.seekToTime().
 *  @param {Event} event Seek event sent from the player.
 *  @return {boolean|number} True if we want the seek to happen as requested, false if we want to
 *      cancel the seek, or an integer to seek to that time instead of the requested time.
 */
MyApp.prototype.onRequestSeekToTime = function(event) {
  if (this.liveStream) {
    return true;
  }
  
  if (!this.checkForSnapbackOnNextSeek) {
    this.checkForSnapbackOnNextSeek = true;
    return true;
  }
  var lastCuepoint = ads.getPreviousCuepointForStreamTime(event.requestedTime);
  if (!lastCuepoint.played && lastCuepoint.starttime > event.currentTime) {
    // Snap back to the start of the last ad break.
    this.inSnapback = true;
    this.snapbackEndTime = Math.max(event.requestedTime, lastCuepoint.endtime);
    // Return the time of the previous ad break, which will cause the player to seek to that time.
    return lastCuepoint.starttime;
  } else {
    // Return true, and the player will just perform the seek to the requested time.
    return true;
  }
}

/**
 *  Called when the user seeks with fast forward or rewind (click and hold on the left or right side
 *  of the remote). Checks to see if we need to jump back to play a previously unplayed ad.
 *  @param {Event} event Seek event sent from the player.
 */
MyApp.prototype.onStateDidChange = function(event) {
  if (this.liveStream) {
    return;
  }
  
  if (event.state == 'scanning') {
    this.scanStartTime = event.elapsedTime;
  } else if ((event.state == 'loading' || event.state == 'playing') &&
             event.oldState == 'scanning') {
    var lastCuepoint = ads.getPreviousCuepointForStreamTime(event.elapsedTime);
    if (!lastCuepoint.played && lastCuepoint.starttime > this.scanStartTime) {
      this.inSnapback = true;
      this.snapbackEndTime = Math.max(event.elapsedTime, lastCuepoint.endtime);
      this.checkForSnapbackOnNextSeek = false;
      this.player.seekToTime(lastCuepoint.starttime);
    }
  }
}
