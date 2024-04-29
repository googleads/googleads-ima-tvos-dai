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

import UIKit

/// The main view controller displays a list of streams that can be opened in the video player.
class MainViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  private var tableView: UITableView!
  private var streams = [Stream]()
  private var currentIndex = -1
  private var playerViewController: VideoPlayerViewController?

  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = .white

    self.playerViewController = VideoPlayerViewController()

    streams = [
      LiveStream(name: "Live Stream", assetKey: "c-rArva4ShKVIAkNfy6HUQ"),
      VODStream(name: "VOD Stream", cmsID: "2548831", videoID: "tears-of-steel"),
    ]

    setUpTableView()
  }

  func setUpTableView() {
    let width = (self.view.frame.width / 2) - 50
    let height = self.view.frame.height - 450
    let tableFrame: CGRect = CGRect(x: 0, y: 120, width: width, height: height)
    tableView = UITableView(frame: tableFrame, style: .grouped)
    self.view.addSubview(tableView)

    self.tableView.dataSource = self
    self.tableView.delegate = self
  }

  // MARK: - UITableView functionality
  func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return streams.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
    cell.textLabel?.text = "\(streams[indexPath.row].name)"

    return cell
  }

  func tableView(_ tableView: UITableView, didHighlightRowAt indexPath: IndexPath) {
    self.currentIndex = indexPath.item

    self.playerViewController!.stream = streams[currentIndex]
    self.present(self.playerViewController!, animated: true, completion: nil)
  }
}
