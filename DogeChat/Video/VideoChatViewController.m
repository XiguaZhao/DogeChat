//
//  VideoChatViewController.m
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/15.
//  Copyright © 2021 赵锡光. All rights reserved.
//

#import "DogeChat-Swift.h"
#import "VideoChatViewController.h"
#import "OverlayVideoView.h"
#import "FriendVideoView.h"
#import <Masonry/Masonry.h>
#import "Recorder.h"

static CGFloat overlayWidth = 0;

API_AVAILABLE(ios(13.0))
@interface VideoChatViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) OverlayVideoView *overlayVideoView;
@property (nonatomic, strong) VideoProcessor *processor;
@property (nonatomic, strong) FriendVideoView *friendView;
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
    if (@available(iOS 13.0, *)) {
        self.processor = [[VideoProcessor alloc] init];
    }
    overlayWidth = self.view.bounds.size.width / 3;
    if (@available(iOS 13.0, *)) {
        self.friendView = [[FriendVideoView alloc] initWithFrame:self.view.bounds];
        [self.friendView prepare];
    } else {
        return;
    }
    self.overlayVideoView = [[OverlayVideoView alloc] initWithFrame:CGRectZero delegate:self];
    self.overlayVideoView.viewController = self;
    [self.view addSubview:_friendView];
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
    [self.view addGestureRecognizer:swipeDown];
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

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.overlayVideoView.avSession startRunning];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.overlayVideoView.avSession stopRunning];
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (output != self.overlayVideoView.videoOutput) return;
    if (WebSocketManagerAdapter.usernameToAdapter[self.username].readyToSendVideoData) {
        __weak VideoChatViewController *wself = self;
        [self.processor compressAndSend:sampleBuffer arFrame:nil sendHandler:^(NSData * _Nonnull data) {
            __strong VideoChatViewController *strongSelf = wself;
            if (!strongSelf) {
                return;
            }
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
