//
//  XBSWritePacket.h
//  IndustryAssist
//
//  Created by XBS on 16/5/11.
//  Copyright © 2016年 GYBS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XBSWritePacket : NSObject
/**
 *  包的标志
 */
@property (nonatomic,assign) long tag;
/**
 *  时间
 */
@property (nonatomic,assign) NSTimeInterval timeout;
/**
 *  数据
 */
@property (nonatomic,strong) NSData *data;
/**
 *  写入数据偏移量
 */
@property (nonatomic,assign) NSInteger byteIndex;
@end
