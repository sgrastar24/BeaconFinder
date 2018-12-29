//
//  BFAppDelegate.m
//  BeaconFinder
//
//  Created by ohya on 2014/04/21.
//  Copyright (c) 2014年 ohya. All rights reserved.
//

#import "BFAppDelegate.h"
#import "BFBeaconFinder.h"
@import IOBluetooth;

@interface BFAppDelegate ()

@property NSUInteger rowsNum;
@property (weak) IBOutlet NSButton *scanButton;

@end

@implementation BFAppDelegate
{
    BFBeaconFinder *finder;
    NSTimer *updateTimer;
    NSIndexSet *wholeIndexSet;
    NSIndexSet *rssiAndTimestampIndexSet;
    NSDateFormatter *dateFormatter;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSLog(@"applicationDidFinishLaunching");
    
    finder = [[BFBeaconFinder alloc] initWith:_tableView];
    _tableView.delegate = self;
    [_tableView setDataSource:self];
    wholeIndexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 4)];
    rssiAndTimestampIndexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(3, 2)];
    
    dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    
    [finder startSearching];
    
    updateTimer = [NSTimer timerWithTimeInterval:0.5f
                                          target:self
                                        selector:@selector(updateMethod:)
                                        userInfo:nil
                                         repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:updateTimer forMode:NSDefaultRunLoopMode];
}

- (IBAction)scanButtonClick:(id)sender {
    NSLog(@"### scanButtonClick: %ld", (long)_scanButton.state);
    if (!_scanButton.state) {
        [finder stopSearching];
    } else {
        [finder startSearching];
    }
}

- (IBAction)hexCheckboxChanged:(id)sender {
    if (_hexCheckbox.state == NSOnState) {
        NSLog(@"hexCheckboxChanged ON");
    } else {
        NSLog(@"hexCheckboxChanged OFF");
    }
    [_tableView reloadData];
}

- (IBAction)clearButtonClick:(id)sender {
    NSLog(@"### clearButtonClick ###");
    @synchronized(finder.lock) {
        [finder initData];
        _rowsNum = 0;
        [_tableView reloadData];
    }
}

- (void)updateMethod:(NSTimer *)timer
{
//    NSLog(@"updateMethod");

    if (!finder.running) {
        _scanButton.state = 0;
        return;
    }
    
    NSUInteger delta = 0;
    @synchronized(finder.lock) {
        if (finder.foundNewBeacon) {
            delta = finder.beaconInfoArray.count - _rowsNum;
//            NSLog(@"updateMethod: delta=%lu", delta);
            finder.foundNewBeacon = NO;
        }
    }
    
    if (delta > 0) {
        NSRange range = { _rowsNum, delta };
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:range];
        //NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:_rowsNum + 1];
//        NSLog(@"updateMethod: old rowsNum=%lu indexset=%@", _rowsNum, indexSet);
        _rowsNum += delta;
//        NSLog(@"updateMethod: new rowsNum=%lu", _rowsNum);
        [_tableView insertRowsAtIndexes:indexSet withAnimation:NSTableViewAnimationSlideDown];
        return;
    }

    if (finder.refreshIndexSet.count > 0 || finder.rssiUpdatedIndexSet.count > 0) {
        @synchronized(finder.lock) {
            if (finder.refreshIndexSet.count > 0) {
//                NSLog(@"updateMethod: refresh count = %lu", (unsigned long)finder.refreshIndexSet.count);
                [_tableView reloadDataForRowIndexes:finder.refreshIndexSet columnIndexes:wholeIndexSet];
                [finder.refreshIndexSet removeAllIndexes];
            }
            if (finder.rssiUpdatedIndexSet.count > 0) {
//                NSLog(@"updateMethod: rssi update count = %lu", (unsigned long)finder.rssiUpdatedIndexSet.count);
//                NSLog(@"updateMethod: table count = %lu", (unsigned long)_tableView.tableColumns.count);
                [_tableView reloadDataForRowIndexes:finder.rssiUpdatedIndexSet columnIndexes:rssiAndTimestampIndexSet];
                [finder.rssiUpdatedIndexSet removeAllIndexes];
            }
        }
    }
}

// The only essential/required tableview dataSource method
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
//    NSLog(@"numberOfRowsInTableView: rowsNum=%lu", (unsigned long)_rowsNum);
    return _rowsNum;
}

// This method is optional if you use bindings to provide the data
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
//    NSLog(@"viewForTableColumn: row=%lu", (unsigned long)row);
    
    // In IB the tableColumn has the identifier set to the same string as the keys in our dictionary
    NSString *identifier = [tableColumn identifier];
    
    if ([identifier isEqualToString:@"UUIDCell"]) {
        NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
        @synchronized(finder.lock) {
            NSMutableDictionary *infoDic = finder.beaconInfoArray[row];
            NSString *uuid  = infoDic[KEY_UUID];
            cellView.textField.stringValue = uuid;
        }
        return cellView;
    }
    else if ([identifier isEqualToString:@"MajorCell"]) {
        return [self tableView:tableView numericDicKey:KEY_MAJOR identifier:identifier row:row asHex:YES];
    }
    else if ([identifier isEqualToString:@"MinorCell"]) {
        return [self tableView:tableView numericDicKey:KEY_MINOR identifier:identifier row:row asHex:YES];
    }
    else if ([identifier isEqualToString:@"RSSICell"]) {
        return [self tableView:tableView numericDicKey:KEY_RSSI identifier:identifier row:row asHex:NO];
    }
    else if ([identifier isEqualToString:@"TimeCell"]) {
        NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
        @synchronized(finder.lock) {
            NSMutableDictionary *infoDic = finder.beaconInfoArray[row];
            NSDate *time  = infoDic[KEY_TIME];
            cellView.textField.stringValue = [dateFormatter stringFromDate:time];
        }
        return cellView;
    }
    else {
        NSAssert1(NO, @"Unhandled table column identifier %@", identifier);
    }
    return nil;
}

- (NSView *)tableView:(NSTableView *)tableView numericDicKey:(NSString *)dicKey identifier:(NSString *)identifier row:(NSInteger)row asHex:(BOOL)asHex
{
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
    @synchronized(finder.lock) {
        NSMutableDictionary *infoDic = finder.beaconInfoArray[row];
        NSNumber *num = infoDic[dicKey];
        if (asHex && _hexCheckbox.state == NSOnState) {
            cellView.textField.stringValue = [NSString stringWithFormat:@"%04X", num.intValue];
        } else {
            cellView.textField.stringValue = num.stringValue;
        }
    }
    return cellView;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (void)copy:(id)sender
{
    if (finder.beaconInfoArray.count > 0) {
        NSMutableDictionary *infoDic = finder.beaconInfoArray[_tableView.selectedRow];
        NSString *uuid  = infoDic[KEY_UUID];
        NSLog(@"copy uuid=%@", uuid);
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        [pboard declareTypes:[NSArray arrayWithObject:NSPasteboardTypeString] owner:self];
        [pboard setString:uuid forType:NSPasteboardTypeString];
    }
}
@end
