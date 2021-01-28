//
//  Recorder.h
//  DogeChat
//
//  Created by 赵锡光 on 2021/1/23.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol VoiceDelegate <NSObject>

- (void)timeToSendData:(NSData *)data;

@end
@interface Recorder : NSObject

@property (nonatomic, weak) id<VoiceDelegate> delegate;
@property (nonatomic, strong, nullable) NSMutableData *receivedData;

+ (instancetype)sharedInstance;
- (void)startRecord; //开始录音
- (void)stopRecord;  //结束录音
- (void)startPlay;   //开始放音
- (void)stopPlay;    //结束放音

- (void)startRecordAndPlay;  //开始通话
- (void)stopRecordAndPlay;   //结束通话
@end

NS_ASSUME_NONNULL_END
