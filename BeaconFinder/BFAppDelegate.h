//
//  BFAppDelegate.h
//  BeaconFinder
//
//  Created by ohya on 2014/04/21.
//  Copyright (c) 2014年 ohya. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BFAppDelegate : NSObject <NSApplicationDelegate, NSTableViewDelegate, NSTableViewDataSource>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSButton *hexCheckbox;

- (IBAction)scanButtonClick:(id)sender;
- (IBAction)hexCheckboxChanged:(id)sender;
- (IBAction)clearButtonClick:(id)sender;

@end
