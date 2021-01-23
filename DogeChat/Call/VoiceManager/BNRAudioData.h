//
//  BNRAudioData.h
//  DogeChat
//
//  Created by 赵锡光 on 2021/1/22.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudioTypes.h>

@interface BNRAudioData : NSObject
@property (nonatomic,readonly) NSData *data;
@property (nonatomic,readonly) AudioStreamPacketDescription packetDescription;

+ (instancetype)parsedAudioDataWithBytes:(const void *)bytes
                       packetDescription:(AudioStreamPacketDescription)packetDescription;
@end
