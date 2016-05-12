//
//  XBSStreamTool.h
//  IndustryAssist
//
//  Created by XBS on 16/5/10.
//  Copyright © 2016年 GYBS. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XBSStreamTool;

@protocol XBSStreamToolDelegate <NSObject>

@optional
/**
 *  连接服务器地址和端口成功
 */
-(void)didConnectHostAndPort;
/**
 *  写入数据包完毕
 */
-(void)streamTool:(XBSStreamTool *)streamTool didWriteDataWithTag:(long)tag;
/**
 *  写入数据包超时
 */
-(void)streamTool:(XBSStreamTool *)streamTool shouldTimeoutWriteWithTag:(long)tag;
/**
 *  写入数据包错误
 */
-(void)streamTool:(XBSStreamTool *)streamTool didWriteDataErrorWithTag:(long)tag;
/**
 *  连接断开
 */
-(void)didDisConnect:(XBSStreamTool *)streamTool;
/**
 *  读取数据包完毕
 */
-(void)streamTool:(XBSStreamTool *)streamTool didReadData:(NSData *)data WithTag:(long)tag;
/**
 *  读取数据包超时
 */
-(void)streamTool:(XBSStreamTool *)streamTool shouldTimeoutReadWithTag:(long)tag;
@end

@interface XBSStreamTool : NSObject

@property(nonatomic,weak) id<XBSStreamToolDelegate>delegate;

+ (XBSStreamTool*) sharedInstance;
/**
 *  初始化
 */
-(void)initNetworkWithDelegate:(id)delegate;
/**
 *  写入数据
 */
-(void)writeData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag;
/**
 *  读取数据
 */
- (void)readDataToLength:(NSUInteger)length withTimeout:(NSTimeInterval)timeout tag:(long)tag;

@end
