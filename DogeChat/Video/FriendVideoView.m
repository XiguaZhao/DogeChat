//
//  FriendVideoView.m
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/17.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

#import "FriendVideoView.h"
#import "DogeChat-Swift.h"
#import <Foundation/Foundation.h>

@implementation FriendVideoView {
    Renderer *_renderer;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self prepare];
    }
    return self;
}

- (void)prepare {
    self.device = MTLCreateSystemDefaultDevice();
    self.backgroundColor = [UIColor clearColor];
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    _renderer = [[Renderer alloc] initWithDevice:self.device renderDestination:self];
    [_renderer mtkView:self drawableSizeWillChange:self.bounds.size];
    self.delegate = _renderer;
}

- (void)didReceiveData:(NSData *)data {
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
        if (type == 0) {
        }else if (type == 1) {
            // 视频
            VideoFrameData *frameData = [NSJSONSerialization object ]
            __weak MainVideoView *wself = self;
        }
        
    }
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
