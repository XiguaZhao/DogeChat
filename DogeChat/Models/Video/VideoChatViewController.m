//
//  VideoChatViewController.m
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/15.
//  Copyright © 2021 赵锡光. All rights reserved.
//


#import "OverlayVideoView.h"
#import <Masonry/Masonry.h>
#import "DogeChat-Swift.h"
#import "Recorder.h"
@import DogeChatNetwork;

API_AVAILABLE(ios(13.0))
@interface VideoChatViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) FriendVideoView *friendView;
@property (nonatomic, strong) OverlayVideoView *overlayVideoView;
@property (nonatomic, assign) int count;
@property (nonatomic, strong) VideoProcessor *processor;

@end

@implementation VideoChatViewController

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.modalPresentationStyle = UIModalPresentationFullScreen;
        UIApplication.sharedApplication.idleTimerDisabled = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.processor = [VideoProcessor new];
    self.friendView = [[FriendVideoView alloc] initWithFrame:self.view.bounds];
    self.overlayVideoView = [[OverlayVideoView alloc] initWithFrame:CGRectZero delegate:self];
    self.overlayVideoView.viewController = self;
    [_friendView prepare];
    [self.view addSubview:_friendView];
    [self.view addSubview:_overlayVideoView];
    __weak VideoChatViewController *wself = self;
    [_overlayVideoView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(wself.view.mas_safeAreaLayoutGuideTop);
        make.trailing.equalTo(wself.view).offset(-20);
        make.width.mas_equalTo(200 * 72 / 128);
        make.height.mas_equalTo(200);
    }];
    _count = 0;
    UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss)];
    swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    [self.view addGestureRecognizer:swipeDown];
}

- (void)dismiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.overlayVideoView.avSession startRunning];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.overlayVideoView.avSession stopRunning];
    UIApplication.sharedApplication.idleTimerDisabled = false;
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (output != self.overlayVideoView.videoOutput) return;
    if (WebSocketManagerAdapter.usernameToAdapter[self.username].readyToSendVideoData) {
        __weak VideoChatViewController *wself = self;
        [self.processor compressAndSend:sampleBuffer arFrame:nil sendHandler:^(NSData *data) {
            __strong VideoChatViewController *strongSelf = wself;
            strongSelf->_count++;
            NSMutableData *mData = [[NSMutableData alloc] init];
            NSData *headData = [strongSelf bytewithInt:60000];//协议头 4位 (0-4)
            NSData *countData = [strongSelf bytewithInt:strongSelf->_count];//发到第几个包 4位 (4-8)
            NSData *legnthData = [strongSelf bytewithInt:(int)data.length];//当前包的长度 4位 (8-12)
            NSData *dataType = [strongSelf bytewithInt:1];//type 1为视频
            [mData appendData:headData];
            [mData appendData:countData];
            [mData appendData:legnthData];
            [mData appendData:dataType];
            [mData appendData:data];
            NSMutableData *recordedAudioData = Recorder.sharedInstance.recordedData;
            if (recordedAudioData.length) {
                [mData appendData:recordedAudioData];
                [recordedAudioData replaceBytesInRange:NSMakeRange(0, recordedAudioData.length) withBytes:NULL length:0];
            }
            [[self manager] timeToSendData:[mData copy]];
        }];

    }
}

- (WebSocketManagerAdapter *)manager {
    return WebSocketManagerAdapter.usernameToAdapter[self.username];
}

- (void)didReceiveVideoData:(NSData *)videoData {
    [self.friendView didReceiveData:videoData];
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

