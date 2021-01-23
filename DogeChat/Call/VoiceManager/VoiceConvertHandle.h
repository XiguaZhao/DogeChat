//
//  VoiceConvertHandle.h
//  DogeChat
//
//  Created by 赵锡光 on 2021/1/22.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol VoiceConvertHandleDelegate <NSObject>

-(void)covertedData:(NSData *)data;

@end

@interface VoiceConvertHandle : NSObject
@property (nonatomic,weak) id<VoiceConvertHandleDelegate> delegate;
@property (nonatomic)   BOOL    startRecord;
+(instancetype)shareInstance;
-(void)playWithData:(NSData *)data;
@end
