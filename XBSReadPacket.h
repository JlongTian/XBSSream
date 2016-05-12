//
//  XBSReadPacket.h
//  IndustryAssist
//
//  Created by XBS on 16/5/11.
//  Copyright © 2016年 GYBS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XBSReadPacket : NSObject
/**
 *  包的标志
 */
@property (nonatomic,assign) long tag;
/**
 *  数据
 */
@property (nonatomic,strong) NSMutableData *data;
/**
 *  要读取的长度
 */
@property (nonatomic,assign) NSInteger readLength;
/**
 *  要读取的长度
 */
@property (nonatomic,assign) NSInteger remainLength;
/**
 *  时间
 */
@property (nonatomic,assign) NSTimeInterval timeout;

@end
