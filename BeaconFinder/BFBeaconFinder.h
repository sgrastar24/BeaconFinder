//
//  BFBeaconFinder.h
//  BeaconFinder
//
//  Created by ohya on 2014/04/21.
//  Copyright (c) 2014年 ohya. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@import CoreBluetooth;
@import IOBluetooth;

#define KEY_UUID  @"uuid"
#define KEY_MAJOR @"major"
#define KEY_MINOR @"minor"
#define KEY_RSSI  @"rssi"
#define KEY_TIME  @"time"

@interface BFBeaconFinder : NSObject <CBCentralManagerDelegate>

- (instancetype)initWith:(NSTableView *)tableView;
- (void)initData;
- (void)startSearching;
- (void)stopSearching;

@property (nonatomic) BOOL running; // for run/pause button
@property (nonatomic) NSMutableArray *peripheralArray;
@property (nonatomic) NSMutableArray *beaconAdvArray; // ProximityUUID+Major+Minor(binary)
@property (nonatomic) NSMutableArray *beaconInfoArray; // NSDictionary[UUID,Major,Minor,RSSI,Timestamp]
//@property (nonatomic) NSMutableDictionary *beaconDict;
@property (nonatomic) BOOL foundNewBeacon;

@property (nonatomic) NSMutableIndexSet *refreshIndexSet;
@property (nonatomic) NSMutableIndexSet *rssiUpdatedIndexSet;
@property (nonatomic) NSObject *lock;

@end
