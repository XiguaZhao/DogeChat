//
//  SDWebImageManager+TempModifyURLPre.m
//  DogeChat
//
//  Created by 赵锡光 on 2021/8/18.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

#import "SDWebImageManager+TempModifyURLPre.h"
#import <objc/runtime.h>

@implementation SDWebImageManager (TempModifyURLPre)

+ (void)load {
    Method method1 = class_getInstanceMethod(self, @selector(loadImageWithURL:options:progress:completed:));
    Method method2 = class_getInstanceMethod(self, @selector(dogechat_loadImageWithURL:options:progress:completed:));
    method_exchangeImplementations(method1, method2);
}

- (SDWebImageCombinedOperation *)dogechat_loadImageWithURL:(NSURL *)url options:(SDWebImageOptions)options progress:(SDImageLoaderProgressBlock)progressBlock completed:(SDInternalCompletionBlock)completedBlock {
    NSString *ip = @"121.5.152.193";
    NSMutableString *newUrlStr = url.absoluteString.mutableCopy;
    [newUrlStr replaceOccurrencesOfString:@"procwq.top" withString:ip options:NSCaseInsensitiveSearch range:NSMakeRange(0, newUrlStr.length)];
    if (![newUrlStr containsString:ip] && ![newUrlStr hasPrefix:@"https://"]) {
        [newUrlStr insertString:[NSString stringWithFormat:@"https://%@", ip] atIndex:0];
    }
    return [self dogechat_loadImageWithURL:[NSURL URLWithString:newUrlStr] options:options progress:progressBlock completed:completedBlock];
}

@end
