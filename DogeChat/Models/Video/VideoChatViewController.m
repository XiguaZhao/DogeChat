//
//  VideoChatViewController.m
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/15.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

#import "VideoChatViewController.h"
#import "MainVideoView.h"
#import "OverlayVideoView.h"
#import "HJH264Encoder.h"
#import "HJH264Decoder.h"
#import <Masonry/Masonry.h>
#import "DogeChat-Swift.h"

static CGFloat overlayWidth = 0;

@interface VideoChatViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) MainVideoView *mainVideoView;
@property (nonatomic, strong) OverlayVideoView *overlayVideoView;
@property (nonatomic, strong) HJH264Encoder *encoder;
@property (nonatomic, strong) HJH264Decoder *decoder;
@property (nonatomic, strong) HJOpenGLView *playView;
@property(nonatomic, assign) int count;

@end

@implementation VideoChatViewController

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _encoder = [HJH264Encoder new];
    _decoder = [HJH264Decoder new];
    overlayWidth = self.view.bounds.size.width / 3;
    self.mainVideoView = [[MainVideoView alloc] initWithFrame:self.view.bounds];
    self.overlayVideoView = [[OverlayVideoView alloc] initWithFrame:CGRectZero delegate:self];
    self.overlayVideoView.viewController = self;
    [self.view addSubview:_mainVideoView];
    [self.view addSubview:_overlayVideoView];
    __weak VideoChatViewController *wself = self;
    [_overlayVideoView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(wself.view).offset(10 + UIApplication.sharedApplication.statusBarFrame.size.height);
        make.trailing.equalTo(wself.view).offset(-20);
        make.width.mas_equalTo(overlayWidth);
        make.height.mas_equalTo(200);
    }];
    _count = 0;
    UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss)];
    swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
//    [self.view addGestureRecognizer:swipeDown];
}

- (void)dismiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)updateRatioForOverlayVideoView:(CGFloat)width height:(CGFloat)height {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.overlayVideoView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.height.mas_equalTo(height * (width) / overlayWidth);
        }];
    });
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.overlayVideoView.avSession stopRunning];
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (output != self.overlayVideoView.videoOutput) return;
    if (WebSocketManagerAdapter.shared.readyToSendVideoData) {
        [self.encoder startH264EncodeWithSampleBuffer:sampleBuffer andReturnData:^(NSData *data) {
            self->_count++;
            NSMutableData *mData = [[NSMutableData alloc] init];
            NSData *headData = [self bytewithInt:60000];//协议头 4位 (0-4)
            NSData *countData = [self bytewithInt:self->_count];//发到第几个包 4位 (4-8)
            NSData *legnthData = [self bytewithInt:(int)data.length];//当前包的长度 4位 (8-12)
            NSData *dataType = [self bytewithInt:1];//type 1为视频
            [mData appendData:headData];
            [mData appendData:countData];
            [mData appendData:legnthData];
            [mData appendData:dataType];
            [mData appendData:data];
            [WebSocketManager.shared sendVideoData:[mData copy]];
        }];

    }
}

- (void)didReceiveVideoData:(NSData *)videoData {
    [self.mainVideoView didReceiveData:videoData];
}

- (NSData * )bytewithInt:(int )i {
    Byte b1=i & 0xff;
    Byte b2=(i>>8) & 0xff;
    Byte b3=(i>>16) & 0xff;
    Byte b4=(i>>24) & 0xff;
    Byte byte[] = {b4,b3,b2,b1};
    NSData *data = [NSData dataWithBytes:byte length:sizeof(byte)];
    return data;
}

@end
