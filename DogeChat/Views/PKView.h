//
//  PKView.h
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/22.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

#import <PencilKit/PencilKit.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(14.0))
@protocol PKViewChangedDelegate <NSObject>

- (void)pkView:(PKCanvasView *)pkView message:(id __nullable)message addNewStroke:(PKStroke *)newStroke;
- (void)pkView:(PKCanvasView *)pkView message:(id __nullable)message deleteStrokesIndex:(NSArray<NSNumber *> *)deleteStrokesIndex;
- (void)pkViewDidFinishDrawing:(PKCanvasView *)pkView message:(id __nullable)message;

@end

API_AVAILABLE(ios(14.0))
@interface PKView : PKCanvasView

@end

API_AVAILABLE(ios(14.0))
@interface PKViewDelegate : NSObject <PKCanvasViewDelegate>

@property (nonatomic, weak) PKCanvasView *pkView;
@property (nonatomic, weak) id<PKViewChangedDelegate> dataChangedDelegate;
@property (nonatomic, strong, nullable) id message;

@end


NS_ASSUME_NONNULL_END
