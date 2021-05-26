//
//  MainVideoView.h
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/15.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MainVideoView : UIView

@property (nonatomic, assign) BOOL exit;

- (void)didReceiveData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
