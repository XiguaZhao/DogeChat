//
//  PKView.h
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/22.
//  Copyright © 2021 赵锡光. All rights reserved.
//

#import <PencilKit/PencilKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol PKViewChangedDelegate <NSObject>

- (void)pkView:(PKCanvasView *)pkView message:(id __nullable)message addNewStroke:(id)newStroke;
- (void)pkView:(PKCanvasView *)pkView message:(id __nullable)message deleteStrokesIndex:(NSArray<NSNumber *> *)deleteStrokesIndex;
- (void)pkViewDidFinishDrawing:(PKCanvasView *)pkView message:(id __nullable)message;
- (void)pkViewDidCancelDrawing:(PKCanvasView *)pkView message:(id __nullable)message;

@end

@protocol PKViewAutoOffsetDelegate <NSObject>

- (void)shoudAutoOffset:(BOOL)shouldAutoOffset;

@end

@interface PKViewDelegate : NSObject <PKCanvasViewDelegate, PKToolPickerObserver>

@property (nonatomic, weak) PKCanvasView *pkView;
@property (nonatomic, weak) id<PKViewChangedDelegate> dataChangedDelegate;
@property (nonatomic, weak) id<PKViewAutoOffsetDelegate> autoOffsetDelegate;
@property (nonatomic, strong, nullable) id message;

- (void)autoOffset;

@end


NS_ASSUME_NONNULL_END
