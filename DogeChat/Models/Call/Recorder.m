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

#define INPUT_BUS   1
#define OUTPUT_BUS  0
#define kSampleRate 16000 //采样率

static AudioBufferList recordBufferList;
static AudioUnit _recordAudioUnit;

//static NSMutableData *recordPcmData;
static NSMutableData *recordedData;

@interface Recorder ()

@property (assign, nonatomic) BOOL isUnitWorking;
@property (assign, nonatomic) BOOL isRecording;  //录音开关状态
@property (assign, nonatomic) BOOL isPlaying;    //放音开关状态
@property (assign, nonatomic) OSStatus recorderOpenStatus;

@end

@implementation Recorder

static Recorder *sharedInstace = nil;
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstace = [[Recorder alloc] init];
        [sharedInstace initRemoteIO];
    });
    return sharedInstace;
}

- (void)initRemoteIO {
    AudioUnitInitialize(_recordAudioUnit);
    [self initBuffer];
    [self initAudioComponent];
    [self initFormat];
    [self initAudioProperty];
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

- (void)initAudioProperty {
    UInt32 flag = 1;
    AudioUnitSetProperty(_recordAudioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input,
                         INPUT_BUS,
                         &flag,
                         sizeof(flag));
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
    NSLog(@"record buffer size: %u", (unsigned int)recordBufferList.mBuffers[0].mDataByteSize);
    AudioUnitRender(_recordAudioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &recordBufferList);
    if (sharedInstace.isRecording) {
        NSData *pcmData = [NSData dataWithBytes:recordBufferList.mBuffers[0].mData length:recordBufferList.mBuffers[0].mDataByteSize];
        if (pcmData && pcmData.length > 0) {
            [sharedInstace.delegate timeToSendData:pcmData];
            NSLog(@"发出去的dataLen:%lu", (unsigned long)pcmData.length);
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
    NSUInteger receivedLen = sharedInstace.receivedData.length;
    if (sharedInstace.receivedData.length >= buffLen) {
        NSUInteger throttleLen = buffLen * 40;
        if (receivedLen > throttleLen) {
            [sharedInstace.receivedData replaceBytesInRange:NSMakeRange(0, receivedLen - buffLen) withBytes:NULL length:0];
        }
        
        NSData *data = [sharedInstace.receivedData subdataWithRange:NSMakeRange(0, buffLen)];
        AudioBuffer inBuffer = ioData->mBuffers[0];
        memcpy(inBuffer.mData, data.bytes, data.length);
        inBuffer.mDataByteSize = (UInt32)data.length;
        [sharedInstace.receivedData replaceBytesInRange:NSMakeRange(0, buffLen) withBytes:NULL length:0];
    }else {
        for (UInt32 i=0; i < ioData->mNumberBuffers; i++)
        {
            memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
        }
    }
    return noErr;
}

- (void)initAudioSession {
    [AVAudioSession.sharedInstance setActive:NO error:nil];
    NSError *error;
    if (AVAudioSession.sharedInstance.category != AVAudioSessionCategoryPlayAndRecord) {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionAllowBluetooth error:&error];
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
    self.isUnitWorking = YES;
}

- (void)setRecorderOpenStatus:(OSStatus)recorderOpenStatus {
    _recorderOpenStatus = recorderOpenStatus;
    if (recorderOpenStatus != noErr) {
        dispatch_after(DISPATCH_TIME_NOW + 1 * NSEC_PER_SEC, dispatch_get_main_queue(), ^{
            [self initAudioSession];
        });
    }
}

#pragma mark - public methods

- (void)startRecord {
    NSLog(@"开始录音");
    self.isRecording = YES;
    recordedData = [NSMutableData data];
}

- (void)stopRecord {
    NSLog(@"暂停录音");
    self.isRecording = NO;
}

- (void)startPlay {
    NSLog(@"开始放音");
    self.isPlaying = YES;
    _receivedData = [NSMutableData data];
}

- (void)stopPlay {
    NSLog(@"暂停放音");
    self.isPlaying = NO;
}

- (void)startRecordAndPlay {
    if (self.isUnitWorking) {
        NSLog(@"通话中...");
        return;
    }
    NSLog(@"开始通话");
    if (recordedData) {
        recordedData = nil;
    }
    recordedData = [NSMutableData data];
    sharedInstace.receivedData = [NSMutableData data];
    [self startRecord];
    [self startPlay];
    [self initAudioSession];
}

- (void)stopRecordAndPlay {
    NSLog(@"结束通话");
    AudioOutputUnitStop(_recordAudioUnit);
    self.isUnitWorking = NO;
    [self stopRecord];
    [self stopPlay];
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

@end
