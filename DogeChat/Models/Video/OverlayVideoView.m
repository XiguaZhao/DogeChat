//
//  OverlayVideoView.m
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/15.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

#import "OverlayVideoView.h"

@interface OverlayVideoView ()

@property (nonatomic, weak) id<AVCaptureVideoDataOutputSampleBufferDelegate> delegate;
@property (nonatomic, strong)   AVCaptureVideoPreviewLayer  *previewLayer;

@end

@implementation OverlayVideoView {
    BOOL _nowUseFront;
    AVCaptureDeviceType _nowUseType;
}

- (instancetype)initWithFrame:(CGRect)frame delegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)delegate {
    self = [super initWithFrame:frame];
    if (self) {
        self.delegate = delegate;
        [self prepare];
    }
    return self;
}

- (void)prepare {
    // 设备对象 (video)
    AVCaptureDevice *inputCamera = [self getCameraWithFront:YES type:AVCaptureDeviceTypeBuiltInWideAngleCamera];
    [self setupSessionWithCamera:inputCamera];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(switchCameraAction)];
    [self addGestureRecognizer:tap];
}

- (void)switchCameraAction {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"切换镜头" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    __weak OverlayVideoView *wself = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"前置广角" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [wself switchCameraWithFront:YES type:AVCaptureDeviceTypeBuiltInWideAngleCamera];
    }]];
//    if (@available(iOS 13.0, *)) {
//        [alert addAction:[UIAlertAction actionWithTitle:@"前置超广角" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
//            [wself switchCameraWithFront:YES type:AVCaptureDeviceTypeBuiltInUltraWideCamera];
//        }]];
//    }
    [alert addAction:[UIAlertAction actionWithTitle:@"后置广角" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [wself switchCameraWithFront:NO type:AVCaptureDeviceTypeBuiltInWideAngleCamera];
    }]];
    if (@available(iOS 13.0, *)) {
        [alert addAction:[UIAlertAction actionWithTitle:@"后置超广角" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [wself switchCameraWithFront:NO type:AVCaptureDeviceTypeBuiltInUltraWideCamera];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"后置倍镜" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [wself switchCameraWithFront:NO type:AVCaptureDeviceTypeBuiltInTelephotoCamera];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
    }]];
    [self.viewController presentViewController:alert animated:YES completion:nil];
}

- (void)switchCameraWithFront:(BOOL)isFront type:(AVCaptureDeviceType)type {
    if (_nowUseType == type && _nowUseFront == isFront) {
        return;
    }
    [self.avSession stopRunning];
    AVCaptureDevice *camera = [self getCameraWithFront:isFront type:type];
    if (!camera) {
        camera = [self getCameraWithFront:YES type:AVCaptureDeviceTypeBuiltInWideAngleCamera];
    }
    [self.previewLayer removeFromSuperlayer];
    [self setupSessionWithCamera:camera];
    [self.avSession startRunning];
}

- (void)setupSessionWithCamera:(AVCaptureDevice *)inputCamera {
    self.avSession = [[AVCaptureSession alloc] init];
    self.avSession.sessionPreset = AVCaptureSessionPreset1280x720;
    
    AVCaptureDeviceInput *videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:inputCamera error:nil];
    
    if ([self.avSession canAddInput:videoInput]) {
        [self.avSession addInput:videoInput];
    }
    
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.videoOutput setAlwaysDiscardsLateVideoFrames:YES];  // 是否抛弃延迟的帧：NO
    
    [self.videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    [self.videoOutput setSampleBufferDelegate:self.delegate queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    if ([self.avSession canAddOutput:self.videoOutput]) {
        [self.avSession addOutput:self.videoOutput];
    }
    AVCaptureConnection *connection = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];
    [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.avSession];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [[self.previewLayer connection] setVideoOrientation:AVCaptureVideoOrientationPortrait];
    [self.layer addSublayer:self.previewLayer];
}

- (AVCaptureDevice *)getCameraWithFront:(BOOL)isFront type:(AVCaptureDeviceType)type {
    AVCaptureDeviceDiscoverySession *session = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[type] mediaType:AVMediaTypeVideo position:(isFront ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack)];
    AVCaptureDevice *camera = session.devices.firstObject;
    [camera lockForConfiguration:nil];
    camera.activeVideoMinFrameDuration = CMTimeMake(1, 30);
    [camera unlockForConfiguration];
    _nowUseFront = isFront;
    _nowUseType = type;
    return camera;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.previewLayer.frame = self.bounds;
}

@end
