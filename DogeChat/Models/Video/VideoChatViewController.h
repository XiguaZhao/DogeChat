//
//  VideoChatViewController.h
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/15.
//  Copyright © 2021 赵锡光. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface VideoChatViewController : UIViewController
- (void)didReceiveVideoData:(NSData *)videoData;
- (void)dismiss;
@end

NS_ASSUME_NONNULL_END
