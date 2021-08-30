//
//  LivePhotoGenerator.m
//  DogeChat
//
//  Created by 赵锡光 on 2021/8/27.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

#import "LivePhotoGenerator.h"
#import <CoreServices/CoreServices.h>
#import <AVFoundation/AVFoundation.h>
#import "DogeChat-Swift.h"
#import "LFAssetExportSession.h"

#pragma GCC diagnostic ignored "-Wundeclared-selector"

#define PATH_TEMP_FILE(name)      [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:name]
#define PATH_IMAGE_FILE(name)     [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:name]
#define PATH_MOVIE_FILE(name)     [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:name]

@implementation LivePhotoGenerator

- (void)generateForLivePhoto:(PHLivePhoto *)livePhoto completion:(nonnull void (^)(PHLivePhoto * _Nonnull))completion {
    NSString *uuid = [[NSUUID new] UUIDString];
    NSURL *imageURL = [livePhoto performSelector:@selector(imageURL)];
    NSURL *videoURL = [livePhoto performSelector:@selector(videoURL)];
    NSData *imageData = [self generateStillImageURL:imageURL uuid:uuid];
    NSString *tempUUID = [[NSUUID new] UUIDString];
    NSString *tempVideoFilePath = PATH_TEMP_FILE([tempUUID stringByAppendingString:@".mov"]);
    NSString *imagePath = PATH_IMAGE_FILE([uuid stringByAppendingString:@".jpeg"]);
    [imageData writeToFile:imagePath atomically:YES];
    [self compressVideoWithInputURL:videoURL outputURL:[NSURL fileURLWithPath:tempVideoFilePath] quality:VideoQuality540 compressType:VideoCompressTypeThirdParty completion:^{
        QuickTimeMov *qtmov = [[QuickTimeMov alloc] initWithPath:tempVideoFilePath];
        NSString *videoPath = PATH_MOVIE_FILE([uuid stringByAppendingString:@".mov"]);
        [qtmov write:videoPath assetIdentifier:uuid];
        [NSFileManager.defaultManager removeItemAtURL:imageURL error:nil];
        [NSFileManager.defaultManager removeItemAtURL:videoURL error:nil];
        [PHLivePhoto requestLivePhotoWithResourceFileURLs:@[[NSURL fileURLWithPath:imagePath], [NSURL fileURLWithPath:videoPath]] placeholderImage:nil targetSize:CGSizeZero contentMode:PHImageContentModeAspectFit resultHandler:^(PHLivePhoto * _Nullable livePhoto, NSDictionary * _Nonnull info) {
            if (info.count == 1 && info[PHLivePhotoInfoCancelledKey]) {
                completion(livePhoto);
            }
        }];
    }];
}

- (NSData *)generateStillImageURL:(NSURL *)imageURL uuid:(NSString *)uuid {
    UIImage *image = [[UIImage alloc] initWithData:[NSData dataWithContentsOfURL:imageURL]];
    CGFloat screenWidth = [[AppDelegate shared] widthForSide:SplitVCSideRight] * 0.5;
    CGSize size = CGSizeMake(screenWidth, screenWidth / image.size.width * image.size.height);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    image = UIGraphicsGetImageFromCurrentImageContext();
    NSData *data = UIImageJPEGRepresentation(image, 0.1);
    image = [UIImage imageWithData:data];
    UIGraphicsEndImageContext();
    CGImageRef ref = image.CGImage;
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    
    NSDictionary *kFigAppleMakerNote_AssetIdentifier = [NSDictionary dictionaryWithObject:uuid forKey:@"17"];
    [metadata setObject:kFigAppleMakerNote_AssetIdentifier forKey:@"{MakerApple}"];
    
    NSMutableData *imageData = [[NSMutableData alloc] init];
    CGImageDestinationRef dest = CGImageDestinationCreateWithData((CFMutableDataRef)imageData, kUTTypeJPEG, 1, nil);
    CGImageDestinationAddImage(dest, ref, (CFDictionaryRef)metadata);
    CGImageDestinationFinalize(dest);
    
    return imageData;
}

- (void)compressVideoWithInputURL:(NSURL *)inputURL outputURL:(NSURL *)outputURL quality:(VideoQuality)quality compressType:(VideoCompressType)compressType completion:(void (^)(void))completion {
    switch (compressType) {
        case VideoCompressTypeSystem: {
            AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:[AVURLAsset assetWithURL:inputURL] presetName:[self qualitySystem:quality]];
            session.outputURL = outputURL;
            session.outputFileType = AVFileTypeQuickTimeMovie;
            session.shouldOptimizeForNetworkUse = YES;
            [session exportAsynchronouslyWithCompletionHandler:completion];
        }
            break;
            
        default: {
            LFAssetExportSession *session = [[LFAssetExportSession alloc] initWithAsset:[AVURLAsset assetWithURL:inputURL] preset:[self quality:quality]];
            session.outputURL = outputURL;
            session.outputFileType = AVFileTypeQuickTimeMovie;
            [session exportAsynchronouslyWithCompletionHandler:completion];
        }
            break;
    }
}

- (NSString *)qualitySystem:(VideoQuality)qualityType {
    switch (qualityType) {
        case VideoQuality360:
            return AVAssetExportPresetMediumQuality;
        case VideoQuality480:
            return AVAssetExportPreset640x480;
        case VideoQuality540:
            return AVAssetExportPreset960x540;
        case VideoQuality720:
            return AVAssetExportPreset1280x720;
        case VideoQuality1080:
            return AVAssetExportPreset1920x1080;
    }
}

- (LFAssetExportSessionPreset)quality:(VideoQuality)qualityType {
    switch (qualityType) {
        case VideoQuality360:
            return LFAssetExportSessionPreset360P;
        case VideoQuality480:
            return LFAssetExportSessionPreset480P;
        case VideoQuality540:
            return LFAssetExportSessionPreset540P;
            break;
        case VideoQuality720:
            return LFAssetExportSessionPreset720P;
        case VideoQuality1080:
            return LFAssetExportSessionPreset1080P;
    }
}

@end
