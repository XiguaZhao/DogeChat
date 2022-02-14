//
//  UIViewController+InteractiveTransition.m
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/17.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

#import "UIViewController+InteractiveTransition.h"
#import <objc/runtime.h>

static char *dogechat_interactiveKey;

@implementation UIViewController (InteractiveTransition)

- (id)dogechat_interactive {
    return objc_getAssociatedObject(self, dogechat_interactiveKey);
}

- (void)setDogechat_interactive:(id)dogechat_interactive {
    objc_setAssociatedObject(self, dogechat_interactiveKey, dogechat_interactive, OBJC_ASSOCIATION_RETAIN);
}

@end
