//
//  XBSReadPacket.m
//  IndustryAssist
//
//  Created by XBS on 16/5/11.
//  Copyright © 2016年 GYBS. All rights reserved.
//

#import "XBSReadPacket.h"

@implementation XBSReadPacket

-(NSMutableData *)data{
    
    if (_data==nil) {
        _data = [NSMutableData data];
    }
    return _data;
    
}
@end
