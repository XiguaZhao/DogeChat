//
//  OverlayVideoView.h
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/15.
//  Copyright © 2021 赵锡光. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OverlayVideoView : UIView

@property (nonatomic, weak) UIViewController *viewController;

@property (nonatomic, strong)   AVCaptureSession            *avSession;
@property (nonatomic , strong)  AVCaptureVideoDataOutput    *videoOutput; //

- (instancetype)initWithFrame:(CGRect)frame delegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
