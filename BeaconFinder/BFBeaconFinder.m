//
//  BFBeaconFinder.m
//  BeaconFinder
//
//  Created by ohya on 2014/04/21.
//  Copyright (c) 2014年 ohya. All rights reserved.
//

#import "BFBeaconFinder.h"

@interface BFBeaconFinder ()

@property CBCentralManager *centralManager;
@property BOOL state;
@property BOOL waitForOn;

@end

@implementation BFBeaconFinder

- (instancetype)initWith:(NSTableView *)tableView
{
    self = [super init];
    if (self) {
        self.running = NO;
        //self.tableView = tableView;
        self.peripheralArray = [[NSMutableArray alloc] init];
        self.beaconAdvArray = [[NSMutableArray alloc] init];
        self.beaconInfoArray = [[NSMutableArray alloc] init];
        self.refreshIndexSet = [NSMutableIndexSet indexSet];
        self.rssiUpdatedIndexSet = [NSMutableIndexSet indexSet];
        
        NSDictionary *initOpts = @{CBCentralManagerOptionShowPowerAlertKey: @YES };
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:initOpts];
        
        self.state = NO;
        self.waitForOn = NO;
    }
    return self;
}

- (void)initData
{
    self.peripheralArray = [[NSMutableArray alloc] init];
    self.beaconAdvArray = [[NSMutableArray alloc] init];
    self.beaconInfoArray = [[NSMutableArray alloc] init];
    self.refreshIndexSet = [NSMutableIndexSet indexSet];
    self.rssiUpdatedIndexSet = [NSMutableIndexSet indexSet];
}

- (void)startSearching
{
    self.running = YES;
    if (self.state) {
        NSLog(@">>> startSearching");
        NSDictionary *scanOpts = @{CBCentralManagerScanOptionAllowDuplicatesKey: @YES};  // 重複許可
        [_centralManager scanForPeripheralsWithServices:nil options:scanOpts];
    } else {
        self.waitForOn = YES;
    }
}

- (void)stopSearching
{
    NSLog(@">>> stopSearching");
    self.running = NO;
    self.waitForOn = NO;
    if (_centralManager.isScanning) {
        [_centralManager stopScan];
    }
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSString *stateStr = nil;
    switch (central.state) {
        case CBCentralManagerStateUnknown: stateStr = @"CBCentralManagerStateUnknown"; break;
        case CBCentralManagerStateResetting: stateStr = @"CBCentralManagerStateResetting"; break;
        case CBCentralManagerStateUnsupported: stateStr = @"CBCentralManagerStateUnsupported"; break;
        case CBCentralManagerStateUnauthorized: stateStr = @"CBCentralManagerStateUnauthorized"; break;
        case CBCentralManagerStatePoweredOff: stateStr = @"CBCentralManagerStatePoweredOff"; break;
        case CBCentralManagerStatePoweredOn: stateStr = @"CBCentralManagerStatePoweredOn"; break;
    }
    NSLog(@"centralManagerDidUpdateState: state=%@", stateStr);
    
    if (central.state == CBCentralManagerStatePoweredOn) {
        self.state = YES;
        if (self.waitForOn) {
            self.waitForOn = NO;
            [self startSearching];
        }
    } else {
        self.running = NO;
        self.state = NO;
    }
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    NSData *manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey];
    
    if (manufacturerData && manufacturerData.length > 0) {
        //NSLog(@"advertisement: manuData=%@ len=%d", manufacturerData, manufacturerData.length);
        uint32_t *ptr = (uint32_t *)manufacturerData.bytes;
        //uint16_t *ptr = (uint16_t *)manufacturerData.bytes;
        //NSLog(@"advertisement: *ptr=%x", *ptr);
        if (*ptr == 0x1502004c) { /* Apple */
            [self foundBeacon:peripheral data:(unsigned char *)ptr + 4 RSSI:RSSI];
        }
    }
}

- (void)foundBeacon:(CBPeripheral *)peripheral data:(unsigned char *)data RSSI:(NSNumber *)RSSI
{
    NSDate *timestamp = [NSDate date];
    int index = [self getIndex:peripheral];
    if (index == -1) {
        [self addBeacon:peripheral data:data RSSI:RSSI timestamp:timestamp];
        _foundNewBeacon = YES;
        return;
    }
    
    [self updateBeacon:index data:data RSSI:RSSI timestamp:timestamp];
}

- (void)addBeacon:(CBPeripheral *)peripheral data:(unsigned char *)data RSSI:(NSNumber *)RSSI timestamp:(NSDate *)timestamp
{
    NSData *advData = [self getAdvData:data];
    NSDictionary *advDic = [self makeAdvDic:data RSSI:RSSI timestamp:timestamp];
    
    @synchronized(_lock) {
        [_peripheralArray addObject:[[peripheral identifier] UUIDString]];
        [_beaconAdvArray addObject:advData];
        [_beaconInfoArray addObject:advDic];
//        [_beaconRssiArray addObject:RSSI];
    }
}

- (void)updateBeacon:(int)index data:(unsigned char *)data RSSI:(NSNumber *)RSSI timestamp:(NSDate *)timestamp
{
    NSData *newAdv = [self getAdvData:data];
    NSData *storedAdv = _beaconAdvArray[index];

    // ProximityUUID, Major, Minor が変わっているかチェック
    bool isAdvUpdated = ![newAdv isEqualToData:storedAdv];
    
    @synchronized(_lock) {
        if (isAdvUpdated) {
            // update whole advertisement data
            NSLog(@"update index: %d", index);
            _beaconAdvArray[index] = newAdv;
            _beaconInfoArray[index] = [self makeAdvDic:data RSSI:RSSI timestamp:timestamp];
            // TableView の更新すべき行の情報を作成
            [_refreshIndexSet addIndex:index];
        } else {
            // update RSSI only
            [self updateAdv:index RSSI:RSSI timstamp:timestamp];
            // TableView の更新すべき行の情報を作成
            [_rssiUpdatedIndexSet addIndex:index];
        }

    }
}

- (NSData *)getAdvData:(unsigned char *)data
{
    return [NSData dataWithBytes:data length:20]; // UUID/Major/Minor
}

- (NSMutableDictionary *)makeAdvDic:(unsigned char *)data RSSI:(NSNumber *)RSSI timestamp:(NSDate *)timestamp
{
    NSString *uuid = [NSString stringWithFormat:@"%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
                         data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7],
                         data[8], data[9], data[10], data[11], data[12], data[13], data[14], data[15]];

    unsigned short majorVal = (data[16] << 8) | data[17];
    unsigned short minorVal = (data[18] << 8) | data[19];
    NSNumber *major = [NSNumber numberWithUnsignedShort:majorVal];
    NSNumber *minor = [NSNumber numberWithUnsignedShort:minorVal];

    NSLog(@"[NEW] UUID: %@  major: %@ minor:%@", uuid, major, minor);

    //NSDictionary *infoDic = @{ KEY_UUID:[uuid uppercaseString], KEY_MAJOR:major, KEY_MINOR:minor };
    NSMutableDictionary *advDic = [@{ KEY_UUID:[uuid uppercaseString], KEY_MAJOR:major, KEY_MINOR:minor, KEY_RSSI:RSSI, KEY_TIME:timestamp } mutableCopy];

    return advDic;
}

// call inside synchronize
- (void)updateAdv:(int)index RSSI:(NSNumber *)RSSI timstamp:(NSDate *)timestamp
{
    NSMutableDictionary *advDic = _beaconInfoArray[index];
    advDic[KEY_RSSI] = RSSI;
    advDic[KEY_TIME] = timestamp;
}

- (int)getIndex:(CBPeripheral *)peripheral
{
    NSString *foundId = [[peripheral identifier] UUIDString];
    NSUInteger num = _peripheralArray.count;
    
    for (int index = 0; index < num; index++) {
        NSString *storedId = _peripheralArray[index];
        if ([foundId isEqual:storedId]) {
            return index;
        }
    }
    return -1;
}
@end
