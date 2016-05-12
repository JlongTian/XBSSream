//
//  XBSStreamTool.m
//  IndustryAssist
//
//  Created by XBS on 16/5/10.
//  Copyright © 2016年 GYBS. All rights reserved.
//

#import "XBSStreamTool.h"
#import "XBSWritePacket.h"
#import "XBSReadPacket.h"
#import "MessageProtocol.h"

#define WRITE_CHUNKSIZE    1024   // Limit on size of each write pass
#define kBufferSize 1024


@interface XBSStreamTool ()<NSStreamDelegate>
/**
 *  输入流
 */
@property (nonatomic, strong) NSInputStream *inputStream;
/**
 *  输入流
 */
@property (nonatomic, strong) NSOutputStream *outputStream;
/**
 *  输入流是否开启完毕
 */
@property (nonatomic,assign) BOOL isInPutComoplete;
/**
 *  输出流是否开启完毕
 */
@property (nonatomic,assign) BOOL isOutPutComoplete;
/**
 *  当前写入包
 */
@property (nonatomic,strong) XBSWritePacket *currentWritePacket;
/**
 *  要写入的包数组
 */
@property (nonatomic,strong) NSMutableArray *theWritePackets;
/**
 *  写入定时器
 */
@property (nonatomic,strong) NSTimer *theWriteTimer;
/**
 *  当前读取包
 */
@property (nonatomic,strong) XBSReadPacket *currentReadPacket;
/**
 *  要读取的包数组
 */
@property (nonatomic,strong) NSMutableArray *theReadPackets;
/**
 *  读取定时器
 */
@property (nonatomic,strong) NSTimer *theReadTimer;



@end

@implementation XBSStreamTool

-(NSMutableArray *)theWritePackets{
    
    if (_theWritePackets==nil) {
        
        _theWritePackets = [NSMutableArray array];
        
    }
    
    return _theWritePackets;
    
}

-(NSMutableArray *)theReadPackets{
    
    if (_theReadPackets==nil) {
        
        _theReadPackets = [NSMutableArray array];
        
    }
    
    return _theReadPackets;
    
}

+ (XBSStreamTool*) sharedInstance
{
    static XBSStreamTool *inst;
    if (inst == nil) {
        inst =[[XBSStreamTool alloc] init];
    }
    
    return inst;
}

-(void)initNetworkWithDelegate:(id)delegate{
    
    if (_delegate==nil) {
        _delegate = delegate;
    }
    
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    
    CFStreamCreatePairWithSocketToHost(NULL,
                                       
                                       (CFStringRef)SOCK_IP, SOCK_PORT, &readStream, &writeStream);
    
    _inputStream = (__bridge_transfer NSInputStream *)readStream;
    
    _outputStream = (__bridge_transfer NSOutputStream*)writeStream;
    
    [_inputStream setDelegate:self];
    
    [_outputStream setDelegate:self];
    
    [_inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
     
                            forMode:NSDefaultRunLoopMode];
    
    [_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
     
                             forMode:NSDefaultRunLoopMode];
    
    [_inputStream open];
    
    [_outputStream open];
    
}

/**
 *  输入流和输出流都会回调此函数
 */
- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventOpenCompleted://流打开完毕
        {
            IWLog(@"NSStreamEventOpenCompleted");
            if ([stream isKindOfClass:[NSInputStream class]]) {
                _isInPutComoplete = YES;
            }
            if ([stream isKindOfClass:[NSOutputStream class]]) {
                _isOutPutComoplete = YES;
            }
            
            if (_isInPutComoplete && _isOutPutComoplete) {
                
                if ([self.delegate respondsToSelector:@selector(didConnectHostAndPort)]) {
                    [self.delegate didConnectHostAndPort];
                }
                
            }
            
        }
            break;
        case NSStreamEventHasBytesAvailable://有数据可以获取
        {
            IWLog(@"NSStreamEventHasBytesAvailable");
            [self doReadPacket];
            
        }
            break;
        case NSStreamEventHasSpaceAvailable://可以写入数据
        {
            IWLog(@"NSStreamEventHasSpaceAvailable");
            [self doWritePacket];
            
        }
            break;
        case NSStreamEventErrorOccurred://流发生了错误
        {
            IWLog(@"NSStreamEventErrorOccurred");
            [self close];
        }
            break;
        case NSStreamEventEndEncountered://输入或者输出一个包结束
        {
            [self close];
            IWLog(@"NSStreamEventEndEncountered");
        }
            break;
            
        default:
            break;
    }
    
    
}

-(void)writeData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag{
    
    if (data==nil){
        IWLog(@"亲，数据为空啊！");
        return;
    }
    
    //1.封装数据包
    XBSWritePacket *writePacket = [[XBSWritePacket alloc] init];
    writePacket.tag = tag;
    writePacket.data = data;
    writePacket.timeout = timeout;
    [self.theWritePackets addObject:writePacket];
    
    //2.发送数据包
    [self performSelector:@selector(maybeDequeueWrite) withObject:nil afterDelay:0 inModes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
    //[self maybeDequeueWrite];
    
}

- (void)readDataToLength:(NSUInteger)length withTimeout:(NSTimeInterval)timeout tag:(long)tag{
    
    if (length == 0) return;
    
    XBSReadPacket *readPacket = [[XBSReadPacket alloc] init];
    readPacket.tag = tag;
    readPacket.remainLength = length;
    readPacket.readLength = length;
    readPacket.timeout = timeout;
    [self.theReadPackets addObject:readPacket];
    
    //2.发送数据包
    [self performSelector:@selector(maybeDequeueRead) withObject:nil afterDelay:0 inModes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];

    
}

/**
 *  接收数据包
 */
-(void)maybeDequeueRead{
    
    if (self.currentReadPacket==nil && self.inputStream!=nil) {
        
        if (self.theReadPackets.count>0) {
            
            //1.取出第一个数据包来发送
            self.currentReadPacket = [self.theReadPackets objectAtIndex:0];
            
            //2.删除掉正在发送的数据包
            [self.theReadPackets removeObjectAtIndex:0];
            
            // Start time-out timer
            if(self.currentReadPacket.timeout >= 0.0)
            {
                self.theReadTimer = [NSTimer timerWithTimeInterval:self.currentReadPacket.timeout
                                                             target:self
                                                           selector:@selector(doReadTimeout:)
                                                           userInfo:nil
                                                            repeats:NO];
                [[NSRunLoop currentRunLoop]addTimer:self.theReadTimer forMode:NSDefaultRunLoopMode];
                
                
            }
            
            //3.开始写
            [self doReadPacket];
            
        }
        
    }
    
}

/**
 *  取数据包发送
 */
- (void)maybeDequeueWrite{
    
    if (self.currentWritePacket==nil && self.outputStream!=nil) {
        
        if (self.theWritePackets.count>0) {
            
            //1.取出第一个数据包来发送
            self.currentWritePacket = [self.theWritePackets objectAtIndex:0];
            
            //2.删除掉正在发送的数据包
            [self.theWritePackets removeObjectAtIndex:0];
            
            // Start time-out timer
            if(self.currentWritePacket.timeout >= 0.0)
            {
                self.theWriteTimer = [NSTimer timerWithTimeInterval:self.currentWritePacket.timeout
                                                        target:self
                                                      selector:@selector(doWriteTimeout:)
                                                      userInfo:nil
                                                       repeats:NO];
                [[NSRunLoop currentRunLoop] addTimer:self.theWriteTimer forMode:NSDefaultRunLoopMode];
                
                
            }
            
            //3.开始写
            [self doWritePacket];
            
        }
        
    }
    
}

/**
 *  读取数据包
 */
-(void)doReadPacket{
    
    if (self.currentReadPacket==nil) {
        return;
    }
    
    NSUInteger totalBytesRead = 0;
    
    BOOL done = NO;
    BOOL error = NO;

    while (!done && !error && [self.inputStream hasBytesAvailable]) {
        
        NSInteger bufLen = self.currentReadPacket.remainLength>kBufferSize ? kBufferSize : self.currentReadPacket.remainLength;
        
        uint8_t buf[bufLen];
        NSInteger numBytesRead = [self.inputStream read:buf maxLength:bufLen];
        
        if (numBytesRead < 0) {
            
            error = YES;
            
        }else{
            
            [self.currentReadPacket.data appendData:[NSData dataWithBytes:buf length:numBytesRead]];
            self.currentReadPacket.remainLength = self.currentReadPacket.remainLength-bufLen;
            totalBytesRead = totalBytesRead+bufLen;
            done = (totalBytesRead == self.currentReadPacket.readLength);
            
        }
        
    }
    
    if (done) {
        
        [self completeCurrentRead];
        [self maybeDequeueRead];
        
    }else{
        
        [self close];
        
    }
    
    
    
}

/**
 *  发送数据包
 */
-(void)doWritePacket{
    
    if (self.currentWritePacket==nil) {
        return;
    }
    
    NSInteger totaltalWrite = 0;
    int data_len = (int)[self.currentWritePacket.data length];
    BOOL done = NO;
    BOOL error = NO;

    while (!error && !done && [self.outputStream hasSpaceAvailable]) {
        
        //1.整理数据
        uint8_t *readBytes = (uint8_t *)[self.currentWritePacket.data bytes];
        readBytes += self.currentWritePacket.byteIndex;
        NSInteger len = ((data_len - self.currentWritePacket.byteIndex >= WRITE_CHUNKSIZE) ? WRITE_CHUNKSIZE : (data_len-self.currentWritePacket.byteIndex));
        uint8_t buf[len];
        (void)memcpy(buf, readBytes, len);
        
        //2.写入数据
        len = [self.outputStream write:(const uint8_t *)buf maxLength:len];
        
        if (len<0) {
            error = YES;
        }else{
            //3.修改偏移量和已写入的数据长度
            self.currentWritePacket.byteIndex += len;
            totaltalWrite = totaltalWrite+len;
            
            //4.已经读写完毕
            done = (totaltalWrite == data_len);
        }
        
    };
    
    if (done) {
        
        //5.1清除一些全局变量
        [self completeCurrentWrite];
        //5.2继续传包
        [self maybeDequeueWrite];
        
    }else if (error){
        
        if ([self.delegate respondsToSelector:@selector(streamTool:didWriteDataErrorWithTag:)]) {
            [self.delegate streamTool:self didWriteDataErrorWithTag:self.currentWritePacket.tag];
        }
        
        if (self.currentWritePacket != nil) [self endCurrentWrite];
        
    }
    
}

/**
 *  呼叫代理并且清除变量
 */
-(void)completeCurrentWrite{
    
    if ([self.delegate respondsToSelector:@selector(streamTool:didWriteDataWithTag:)]) {
        
        [self.delegate streamTool:self didWriteDataWithTag:self.currentWritePacket.tag];
        
    }
    
    if (self.currentWritePacket != nil) [self endCurrentWrite];
    
}

/**
 *  结束当前数据包的写入
 */
-(void)endCurrentWrite{
    
    self.currentWritePacket = nil;
    
    if (self.theWriteTimer!=nil){
        [self.theWriteTimer invalidate];
        self.theWriteTimer = nil;
    }
    
}

-(void)completeCurrentRead{
    
    if ([self.delegate respondsToSelector:@selector(streamTool:didReadData:WithTag:)]) {
        
        [self.delegate streamTool:self didReadData:self.currentReadPacket.data WithTag:self.currentReadPacket.tag];
        
    }
    
    if (self.currentReadPacket != nil) [self endCurrentRead];
    
}

-(void)endCurrentRead{
    
    self.currentReadPacket = nil;
    if (self.theReadTimer!=nil){
        [self.theReadTimer invalidate];
        self.theReadTimer = nil;
    }
    
}


/**
 *  关闭流
 */
- (void)close
{
    
    //1.将输入和输出流关闭
    [self.inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.inputStream close];
    [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream close];
    
    //2.清除所有全局变量
    if (self.currentWritePacket != nil) [self endCurrentWrite];
    if (self.currentReadPacket != nil) [self endCurrentRead];
    if (self.inputStream!=nil) self.inputStream = nil;
    if (self.outputStream!=nil) self.outputStream = nil;
    self.isInPutComoplete = NO;
    self.isOutPutComoplete = NO;
    [self.theWritePackets removeAllObjects];
    [self.theReadPackets removeAllObjects];
    
    //3.回调连接失败
    if ([self.delegate respondsToSelector:@selector(didDisConnect:)]) {
        
        [self.delegate didDisConnect:self];
        
    }
    
}

/**
 *  写入超时
 */
-(void)doWriteTimeout:(NSTimer *)timer{
    
    if ([self.delegate respondsToSelector:@selector(streamTool:shouldTimeoutWriteWithTag:)]) {
        
        [self.delegate streamTool:self shouldTimeoutWriteWithTag:self.currentWritePacket.tag];
        
    }
    
    [self close];
    
}

/**
 *  读取超时
 */
-(void)doReadTimeout:(NSTimer *)timer{
    
    if ([self.delegate respondsToSelector:@selector(streamTool:shouldTimeoutReadWithTag:)]) {
        
        [self.delegate streamTool:self shouldTimeoutReadWithTag:self.currentReadPacket.tag];
        
    }
    
    [self close];
    
}



@end
