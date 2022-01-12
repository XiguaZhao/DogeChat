//
//  Recorder.h
//  DogeChat
//
//  Created by 赵锡光 on 2021/1/23.
//  Copyright © 2021 Xiguang Zhao. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, AudioRoute) {
    AudioRouteSpeaker,
    AudioRouteHeadphone
};

@protocol VoiceDelegate <NSObject>

- (void)timeToSendData:(NSData *)data;

@end
@interface Recorder : NSObject

@property (nonatomic, weak) id<VoiceDelegate> delegate;
@property (nonatomic, strong, nullable) NSMutableData *receivedData;
@property (nonatomic, assign) BOOL needSendVideo;
@property (nonatomic, assign) AudioRoute nowRoute;
@property (nonatomic, strong) NSMutableData *recordedData;

+ (instancetype)sharedInstance;
- (void)startRecord; //开始录音
- (void)stopRecord;  //结束录音
- (void)startPlay;   //开始放音
- (void)stopPlay;    //结束放音

- (void)startRecordAndPlay;  //开始通话
- (void)stopRecordAndPlay;   //结束通话

- (void)initAudioSession;

- (void)setRouteToOption:(AudioRoute)route;

+ (int)intWithData:(NSData *)data;
+ (int)intWithDataBytes:(char *)byteK;
+ (NSData *)bytewithInt:(int )i;
@end

NS_ASSUME_NONNULL_END
