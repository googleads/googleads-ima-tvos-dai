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

#import "MainViewController.h"

#import "LiveStream.h"
#import "Stream.h"
#import "VideoViewController.h"
#import "VODStream.h"

@interface MainViewController () <UITableViewDataSource, UITableViewDelegate>
@property(nonatomic) UITableView *tableView;
@property(nonatomic) NSArray<Stream *> *streams;
@property(nonatomic) NSInteger currentIndex;
@property(nonatomic) VideoViewController *playerViewController;
@end

@implementation MainViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  NSLog(@"setting up main view controller");
  self.view.backgroundColor = UIColor.grayColor;

  self.playerViewController = [[VideoViewController alloc] init];

  self.streams = @[
    [[LiveStream alloc] initWithName:@"Live Stream"
                            assetKey:@"c-rArva4ShKVIAkNfy6HUQ"
                         networkCode:@"21775744923"],
    [[VODStream alloc] initWithName:@"VOD Stream"
                          contentID:@"2548831"
                            videoID:@"tears-of-steel"
                        networkCode:@"21775744923"],
  ];

  [self setUpTableView];
}

- (void)setUpTableView {
  CGSize frameSize = self.view.frame.size;
  CGFloat width = (frameSize.width / 2) - 50;
  CGFloat height = frameSize.height - 450;
  CGRect tableFrame = CGRectMake(0, 120, width, height);
  self.tableView = [[UITableView alloc] initWithFrame:tableFrame style:UITableViewStyleGrouped];
  [self.view addSubview:self.tableView];

  self.tableView.dataSource = self;
  self.tableView.delegate = self;
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return self.streams.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                 reuseIdentifier:nil];
  cell.textLabel.text = [self.streams objectAtIndex:indexPath.row].name;

  return cell;
}

- (void)tableView:(UITableView *)tableView didHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
  self.currentIndex = indexPath.item;

  self.playerViewController.stream = [self.streams objectAtIndex:self.currentIndex];
  [self presentViewController:self.playerViewController animated:true completion:nil];
}

@end
