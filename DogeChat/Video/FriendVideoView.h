//
//  FriendVideoView.h
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/17.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(13.0))
@interface FriendVideoView : MTKView

@property (nonatomic, weak) VideoProcessor *processor;

- (void)didReceiveData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
