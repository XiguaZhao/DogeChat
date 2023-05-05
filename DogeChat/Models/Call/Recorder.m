//
//  Recorder.m
//  DogeChat
//
//  Created by 赵锡光 on 2021/1/23.
//  Copyright © 2021 Xiguang Zhao. All rights reserved.
//

#import "Recorder.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "DogeChat-Swift.h"

#define INPUT_BUS   1
#define OUTPUT_BUS  0
#define kSampleRate 16000 //采样率

static AudioBufferList recordBufferList;
static AudioUnit _recordAudioUnit;


@interface Recorder ()

@property (assign, nonatomic) OSStatus recorderOpenStatus;
@property (assign, nonatomic) AVAudioSessionCategory category;
 
@end

@implementation Recorder

static Recorder *sharedInstance = nil;
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Recorder alloc] init];
        [sharedInstance initRemoteIO];
    });
    return sharedInstance;
}

- (void)initRemoteIO {
    AudioUnitInitialize(_recordAudioUnit);
    [self initBuffer];
    [self initAudioComponent];
    [self initFormat];
    [self initRecordeCallback];
    [self initPlayCallback];
}

- (void)initBuffer {
    UInt32 flag = 0;
    AudioUnitSetProperty(_recordAudioUnit,
                         kAudioUnitProperty_ShouldAllocateBuffer,
                         kAudioUnitScope_Output,
                         INPUT_BUS,
                         &flag,
                         sizeof(flag));
}

- (void)initAudioComponent {
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    //audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    AudioComponentInstanceNew(inputComponent, &_recordAudioUnit);
}

- (void)initFormat {
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate = kSampleRate;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mChannelsPerFrame = 1;
    audioFormat.mBitsPerChannel = 16;
    audioFormat.mBytesPerPacket = 2;
    audioFormat.mBytesPerFrame = 2;
    
    AudioUnitSetProperty(_recordAudioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &audioFormat,
                         sizeof(audioFormat));
    AudioUnitSetProperty(_recordAudioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         INPUT_BUS,
                         &audioFormat,
                         sizeof(audioFormat));
}

- (void)enableAudioInput {
    UInt32 flag = 1;
    AudioUnitSetProperty(_recordAudioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input,
                         INPUT_BUS,
                         &flag,
                         sizeof(flag));
}

- (void)disableAudioInput {
    UInt32 flag = 0;
    AudioUnitSetProperty(_recordAudioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input,
                         INPUT_BUS,
                         &flag,
                         sizeof(flag));
}

- (void)enableAudioOutput {
    UInt32 flag = 1;
    AudioUnitSetProperty(_recordAudioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Output,
                         OUTPUT_BUS,
                         &flag,
                         sizeof(flag));
}

- (void)initRecordeCallback {
    AURenderCallbackStruct recordCallback;
    recordCallback.inputProc = RecordCallback;
    recordCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(_recordAudioUnit,
                         kAudioOutputUnitProperty_SetInputCallback,
                         kAudioUnitScope_Global,
                         INPUT_BUS,
                         &recordCallback,
                         sizeof(recordCallback));
}

- (void)initPlayCallback {
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(_recordAudioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Global,
                         OUTPUT_BUS,
                         &playCallback,
                         sizeof(playCallback));
}

#pragma mark - callback function

static OSStatus RecordCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData)
{
    UInt16 numSamples=inNumberFrames*1;
    UInt16 samples[numSamples];
    memset (&samples, 0, sizeof (samples));
    recordBufferList.mNumberBuffers = 1;
    recordBufferList.mBuffers[0].mData = samples;
    recordBufferList.mBuffers[0].mNumberChannels = 1;
    recordBufferList.mBuffers[0].mDataByteSize = numSamples*sizeof(UInt16);
    AudioUnitRender(_recordAudioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &recordBufferList);
    if (sharedInstance.isRecording) {
        NSData *pcmData = [NSData dataWithBytes:recordBufferList.mBuffers[0].mData length:recordBufferList.mBuffers[0].mDataByteSize];
        NSMutableData *wholeData = [NSMutableData new];
        NSData *headData = [Recorder bytewithInt:60000];//协议头 4位 (0-4)
        NSData *wantVideo = [Recorder bytewithInt:(int)sharedInstance.audioPurpose];//是否想要视频[4-8]
        NSData *lengthData = [Recorder bytewithInt:(int)pcmData.length];//当前包的长度 4位 (8-12)
        NSData *dataType = [Recorder bytewithInt:(int)sharedInstance.audioType];
        NSData *uuidData = [sharedInstance.uuid ?: [[NSUUID UUID] UUIDString] dataUsingEncoding:NSUTF8StringEncoding];
        if (uuidData.length > 36) {
            uuidData = [uuidData subdataWithRange:NSMakeRange(0, 36)];
        } else if (uuidData.length < 36) {
        }
        [wholeData appendData:headData];
        [wholeData appendData:wantVideo];
        [wholeData appendData:lengthData];
        [wholeData appendData:dataType];
        [wholeData appendData:uuidData];
        [wholeData appendData:pcmData];
        if (pcmData && pcmData.length > 0) {
            [sharedInstance.delegate timeToSendData:wholeData];
        }
        if (sharedInstance.audioType == AudioTypePTT) {
            [sharedInstance.pttAudioData appendData:pcmData];
        }
    }
    return noErr;
}



static OSStatus PlayCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
    UInt32 buffLen = ioData->mBuffers[0].mDataByteSize;
    NSUInteger receivedLen = sharedInstance.receivedData.length;
    if (sharedInstance.receivedData.length >= buffLen) {
        NSUInteger throttleLen = 10000;
        if (receivedLen > throttleLen) {
            [sharedInstance.receivedData replaceBytesInRange:NSMakeRange(0, receivedLen - buffLen) withBytes:NULL length:0];
        }
        
        NSData *data = [sharedInstance.receivedData subdataWithRange:NSMakeRange(0, buffLen)];
        AudioBuffer inBuffer = ioData->mBuffers[0];
        memcpy(inBuffer.mData, data.bytes, data.length);
        inBuffer.mDataByteSize = (UInt32)data.length;
        [sharedInstance.receivedData replaceBytesInRange:NSMakeRange(0, buffLen) withBytes:NULL length:0];
    }else {
        for (UInt32 i=0; i < ioData->mNumberBuffers; i++)
        {
            memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
        }
    }
    return noErr;
}

- (void)initAudioSession {
    if (self.audioType != AudioTypePTT) {
        [AVAudioSession.sharedInstance setActive:NO error:nil];
    }
    if (self.category != [[AVAudioSession sharedInstance] category]) {
        NSError *error;
        [[AVAudioSession sharedInstance] setCategory:self.category withOptions:AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionAllowBluetoothA2DP error:&error];
    }
    //VoiceProcessingIO有一个属性可用来打开(0)/关闭(1)回声消除功能
    UInt32 echoCancellation=0;
    AudioUnitSetProperty(_recordAudioUnit,
                         kAUVoiceIOProperty_BypassVoiceProcessing,
                         kAudioUnitScope_Global,
                         0,
                         &echoCancellation,
                         sizeof(echoCancellation));
    self.recorderOpenStatus = AudioOutputUnitStart(_recordAudioUnit);
    if (self.audioType == AudioTypePTT) {
        self.nowRoute = AudioRouteSpeaker;
    } else {
        self.nowRoute = AudioRouteHeadphone;
    }
}

- (AVAudioSessionCategory)category {
    return AVAudioSessionCategoryPlayAndRecord;
}

- (void)setRouteToOption:(AudioRoute)route {
    switch (route) {
        case AudioRouteSpeaker: {
            [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
            self.nowRoute = AudioRouteSpeaker;
        }
            break;
            
        case AudioRouteHeadphone: {
            [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
            self.nowRoute = AudioRouteHeadphone;
        }
            break;
    }
}

- (void)setRecorderOpenStatus:(OSStatus)recorderOpenStatus {
    _recorderOpenStatus = recorderOpenStatus;
    if (recorderOpenStatus != noErr) {
        dispatch_after(DISPATCH_TIME_NOW + 1 * NSEC_PER_SEC, dispatch_get_main_queue(), ^{
            [self initAudioSession];
        });
    }
}

- (void)setNeedSendVideo:(BOOL)needSendVideo {
    _needSendVideo = needSendVideo;
    if (needSendVideo) {
        self.audioPurpose = AudioPurposeWantVideo;
    }
}

#pragma mark - public methods

- (void)startRecord {
    NSLog(@"开始录音");
    _audioPurpose = AudioPurposeDefault;
    _recordedData = [NSMutableData data];
    self.isRecording = YES;
    [self enableAudioInput];
    [self initAudioSession];
    if (self.audioType == AudioTypePTT) {
        self.pttAudioData = [NSMutableData new];
    }
}

- (void)stopRecord {
    NSLog(@"暂停录音");
    self.isRecording = NO;
    AudioOutputUnitStop(_recordAudioUnit);
    [self disableAudioInput];
}

- (void)startPlay {
    NSLog(@"开始放音");
    self.isPlaying = YES;
    _audioPurpose = AudioPurposeDefault;
    _receivedData = [NSMutableData data];
    [self enableAudioOutput];
    [self initAudioSession];
}

- (void)stopPlay {
    NSLog(@"暂停放音");
    self.isPlaying = NO;
    AudioOutputUnitStop(_recordAudioUnit);
}

- (void)startRecordAndPlay {
    if (self.isPlaying && self.isRecording) {
        NSLog(@"通话中...");
        return;
    }
    NSLog(@"开始通话");
    if (!self.isRecording) {
        [self startRecord];
    }
    if (!self.isPlaying) {
        [self startPlay];
    }
}

- (void)stopRecordAndPlay {
    NSLog(@"结束通话");
    self.audioPurpose = AudioPurposeNeedEnd;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self stopRecord];
        [self stopPlay];
    });
}

- (void)audio_release {
    AudioUnitUninitialize(_recordAudioUnit);
}

//保存录音文件
- (void)saveAudioData:(NSData *)data name:(NSString *)name clearBefore:(BOOL)clear{
    NSString *path=[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]stringByAppendingPathComponent:name];
    if (clear == YES) {
        if ( YES == [[NSFileManager defaultManager] fileExistsAtPath:path] ){
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        }
    }else {
        if (NO == [[NSFileManager defaultManager] fileExistsAtPath:path]) {
            [[NSFileManager defaultManager] createFileAtPath:path contents:data attributes:nil];
        }else {
            NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:path];
            [fileHandle seekToEndOfFile];  //将节点跳到文件的末尾
            [fileHandle writeData:data]; //追加写入数据
            [fileHandle closeFile];
        }
    }
}

+ (int)intWithData:(NSData *)data {
    Byte *byteK = (Byte *)data.bytes;
    int valueK;
    valueK = (int) (((byteK[0] & 0xFF)<<24)
                    |((byteK[1] & 0xFF)<<16)
                    |((byteK[2] & 0xFF)<<8)
                    |(byteK[3] & 0xFF));
    return valueK;
}


+ (int)intWithDataBytes:(char *)byteK {
    // Byte *byteK = (Byte *)data.bytes;
    int valueK;
    valueK = (int) (((byteK[0] & 0xFF)<<24)
                    |((byteK[1] & 0xFF)<<16)
                    |((byteK[2] & 0xFF)<<8)
                    |(byteK[3] & 0xFF));
    return valueK;
}

+ (NSData * )bytewithInt:(int )i {
    Byte b1=i & 0xff;
    Byte b2=(i>>8) & 0xff;
    Byte b3=(i>>16) & 0xff;
    Byte b4=(i>>24) & 0xff;
    Byte byte[] = {b4,b3,b2,b1};
    NSData *data = [NSData dataWithBytes:byte length:sizeof(byte)];
    return data;
}

@end
