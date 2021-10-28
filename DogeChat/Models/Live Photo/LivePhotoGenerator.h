//
//  LivePhotoGenerator.h
//  DogeChat
//
//  Created by 赵锡光 on 2021/8/27.
//  Copyright © 2021 赵锡光. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PhotosUI/PhotosUI.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, VideoQuality) {
    VideoQuality360,
    VideoQuality480,
    VideoQuality720,
    VideoQuality1080,
    VideoQuality540
};

typedef NS_ENUM(NSUInteger, VideoCompressType) {
    VideoCompressTypeSystem,
    VideoCompressTypeThirdParty
};

@interface LivePhotoGenerator : NSObject

- (void)generateForLivePhoto:(PHLivePhoto *)livePhoto windowWidth:(CGFloat)windowWidth completion:(void (^)(PHLivePhoto *livePhoto))completion;

- (void)compressVideoWithInputURL:(NSURL *)inputURL outputURL:(NSURL *)outputURL quality:(VideoQuality)quality compressType:(VideoCompressType)compressType completion:(void (^)(void))completion;

@end

NS_ASSUME_NONNULL_END
