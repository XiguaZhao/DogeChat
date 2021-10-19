//
//  MainVideoView.m
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/15.
//  Copyright © 2021 赵锡光. All rights reserved.
//


#import "MainVideoView.h"
#import "HJH264Decoder.h"
#import "HJOpenGLView.h"
#import <Masonry/Masonry.h>
#if CompileVideo


@interface MainVideoView ()

@property (nonatomic, assign) int sampleRate;
@property (nonatomic, assign) int sampleBits;
@property (nonatomic, assign) int channels;
@property (nonatomic, retain) HJH264Decoder *decoder;
@property (nonatomic, strong) HJOpenGLView  *playView;
@property (nonatomic, strong) NSMutableArray *socketArray;
@property (nonatomic, strong) NSMutableData *completeData;
@property (nonatomic, strong) NSLock *currentLock;

@end

@implementation MainVideoView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self prepare];
    }
    return self;
}

-(HJH264Decoder *)decoder
{
    if (!_decoder) {
        _decoder = [[HJH264Decoder alloc] init];
    }
    return _decoder;
}


- (NSMutableData *)completeData
{
    if (!_completeData) {
        _completeData = [[ NSMutableData alloc] init];
    }
    return _completeData;
}

- (void)prepare {
    self.currentLock = [[NSLock alloc] init];
    //播放器
    self.sampleRate = 8000;
    self.sampleBits = 16;
    self.channels = 1;
    
    self.playView = [[HJOpenGLView alloc] initWithFrame:self.bounds];
    [self addSubview:self.playView];
    [self.playView setupGL];
    [NSThread detachNewThreadSelector:@selector(receiveDataHanle) toTarget:self withObject:nil];
}

- (void)updateRatioForOverlayVideoViewWithWidth:(CGFloat)width height:(CGFloat)height {
    dispatch_async(dispatch_get_main_queue(), ^{
        CGSize size = self.playView.bounds.size;
        if (width == size.width && height == size.height) {
            return;
        }
        CGFloat screenWidth = self.bounds.size.width;
        self.playView.frame = CGRectMake(0, 0, screenWidth, height * (screenWidth / width));
        self.playView.center = self.center;
    });
}


- (void)didReceiveData:(NSData *)data {
    [self.currentLock lock];
     //收到一段data
    [self.completeData appendData:data];
    [self.currentLock unlock];
    
}

- (void)receiveDataHanle {
    while (!_exit) {
        @autoreleasepool {
            if (self.completeData.length <16) {
                usleep(20*1000);
                continue;
            }
            //缓冲队列大小大于16才能继续处理
            NSData *data = [self.completeData copy];
            NSRange range = NSMakeRange(0, 4);
            NSData *headData = [data subdataWithRange:range];
            int head= [self intWithData:headData];
            
            NSRange countRange = NSMakeRange(4,4);
            NSData *countData = [data subdataWithRange:countRange];
            int count = [self intWithData:countData];
            
            NSRange lengthRange = NSMakeRange(8,4);
            NSData *lengthData = [data subdataWithRange:lengthRange];
            int length = [self intWithData:lengthData];
            
            
            NSRange typeRange = NSMakeRange(12,4);
            NSData *typeData = [data subdataWithRange:typeRange];
            int type = [self intWithData:typeData];
            int completeDataLength = length+16;
            //打印字节头  序列号 消息内容长度  这个包总长
            NSLog(@"head=%d count=%d bodylength=%d completeDataLength=%d completeData.length=%lu",head,count,length,completeDataLength,(unsigned long)data.length);
            
            if (data.length>=completeDataLength) {
                //取出body数据
                NSRange dataRange = NSMakeRange(16, length);
                NSData *mData = [data subdataWithRange:dataRange];
                [self.currentLock lock];
//                self.completeData = [[self.completeData subdataWithRange:NSMakeRange(completeDataLength, self.completeData.length - completeDataLength)] mutableCopy];
                [self.completeData replaceBytesInRange:NSMakeRange(0, completeDataLength) withBytes:NULL length:0];
                [self.currentLock unlock];
                if (type == 0) {
                }else if (type == 1) {
                    // 视频
                    __weak MainVideoView *wself = self;
                    [self.decoder startH264DecodeWithVideoData:(char *)mData.bytes andLength:(int)mData.length andReturnDecodedData:^(CVPixelBufferRef pixelBuffer) {
                        [wself updateRatioForOverlayVideoViewWithWidth:CVPixelBufferGetWidth(pixelBuffer) height:CVPixelBufferGetHeight(pixelBuffer)];
                        [wself.playView displayPixelBuffer:pixelBuffer];
                    }];
                }
                
            } else {
                //遇到了拆包 需要继续接收 直到满足 包大小;
                usleep(10*1000);
                continue;
            }
        }
       
    }
    [NSThread exit];
}

- (int)intWithData:(NSData *)data {
    Byte *byteK = (Byte *)data.bytes;
    int valueK;
    valueK = (int) (((byteK[0] & 0xFF)<<24)
                    |((byteK[1] & 0xFF)<<16)
                    |((byteK[2] & 0xFF)<<8)
                    |(byteK[3] & 0xFF));
    return valueK;
}


- (int)intWithDataBytes:(char *)byteK {
    // Byte *byteK = (Byte *)data.bytes;
    int valueK;
    valueK = (int) (((byteK[0] & 0xFF)<<24)
                    |((byteK[1] & 0xFF)<<16)
                    |((byteK[2] & 0xFF)<<8)
                    |(byteK[3] & 0xFF));
    return valueK;
}


@end

#endif
