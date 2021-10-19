//
//  UIViewController+Hook.m
//  DogeChat
//
//  Created by 赵锡光 on 2021/10/12.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

#import "UIViewController+Hook.h"
#import <objc/runtime.h>
#import "DogeChat-Swift.h"
@import DogeChatUniversal;

@implementation UIViewController (Hook)

+ (void)load {
    Method method1 = class_getInstanceMethod(self, @selector(presentViewController:animated:completion:));
    Method method2 = class_getInstanceMethod(self, @selector(dogeChat_presentViewController:animated:completion:));
    method_exchangeImplementations(method1, method2);
}

- (void)dogeChat_presentViewController:(UIViewController *)vc animated:(BOOL)animated completion:(void(^)(void))completion {
    if (@available(iOS 13, *)) {
        if (AppDelegate.shared.isForceDarkMode) {
            vc.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        }
    }
    
    [self dogeChat_presentViewController:vc animated:animated completion:completion];
}

@end
