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

typedef NS_ENUM(NSUInteger, AudioType) {
    AudioTypeVideo = 1,
    AudioTypeVOIP = 2,
    AudioTypePTT = 3,
};

typedef NS_ENUM(NSUInteger, AudioPurpose) {
    AudioPurposeDefault = 0,
    AudioPurposeWantVideo = 1,
    AudioPurposeNeedEnd = 2,
};

@protocol VoiceDelegate <NSObject>

- (void)timeToSendData:(NSData *)data;

@end
@interface Recorder : NSObject

@property (assign, nonatomic) BOOL isRecording;  //录音开关状态
@property (assign, nonatomic) BOOL isPlaying;    //放音开关状态
@property (nonatomic, weak) id<VoiceDelegate> delegate;
@property (nonatomic, strong, nullable) NSMutableData *receivedData;
@property (nonatomic, assign) BOOL needSendVideo;
@property (nonatomic, assign) AudioRoute nowRoute;
@property (nonatomic, assign) AudioType audioType;
@property (nonatomic, assign) AudioPurpose audioPurpose;
@property (nonatomic, strong) NSMutableData *recordedData;
@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) NSMutableData *pttAudioData;

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
