//
//  PKView.m
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/22.
//  Copyright © 2021 赵锡光. All rights reserved.
//

#import "PKView.h"

@interface PKViewDelegate ()

@property (nonatomic, strong) NSArray<PKStroke *> *oldStrokes;
@property (nonatomic, strong) PKStroke *lastStroke;

@end

@implementation PKViewDelegate

- (void)canvasViewDrawingDidChange:(PKCanvasView *)canvasView {
    if ([canvasView.tool isKindOfClass:[PKEraserTool class]]) {
        NSSet<PKStroke *> *nowStrokes = [NSSet setWithArray:canvasView.drawing.strokes];
        NSMutableArray<NSNumber *> *deleteIndexes = [NSMutableArray new];
        [self.oldStrokes enumerateObjectsUsingBlock:^(PKStroke * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (![nowStrokes containsObject:obj]) {
                [deleteIndexes addObject:@(idx)];
            }
        }];
        [deleteIndexes sortUsingComparator:^NSComparisonResult(NSNumber * _Nonnull obj1, NSNumber * _Nonnull obj2) {
            return [obj2 compare:obj1];
        }];
        if (deleteIndexes.count) {
            [self.dataChangedDelegate pkView:self.pkView message:self.message deleteStrokesIndex:[deleteIndexes copy]];
        }
    } else {
        PKStroke *newStroke = canvasView.drawing.strokes.lastObject;
        self.lastStroke = newStroke;
        if (newStroke != nil && ![self.oldStrokes containsObject:newStroke]) {
            [self.dataChangedDelegate pkView:self.pkView message:self.message addNewStroke:newStroke];
        }
        CGRect bounds = [[PKDrawing alloc] initWithStrokes:@[newStroke]].bounds;
        BOOL shouldAutoOffset = NO;
        if (CGRectGetMaxX(bounds) > canvasView.contentOffset.x + canvasView.bounds.size.width * 0.7) {
            shouldAutoOffset = YES;
        }
        if (self.autoOffsetDelegate) {
            [self.autoOffsetDelegate shoudAutoOffset:shouldAutoOffset];
        }
    }
    self.oldStrokes = canvasView.drawing.strokes;
}

- (void)autoOffset {
    if (!_pkView) return;
    CGPoint originalOffset = _pkView.contentOffset;
    originalOffset.x += 0.6 * _pkView.bounds.size.width;
    originalOffset.x = MIN(originalOffset.x, _pkView.contentSize.width - _pkView.bounds.size.width);
    [_pkView setContentOffset:originalOffset animated:YES];
}

- (void)toolPickerSelectedToolDidChange:(PKToolPicker *)toolPicker {
    if ([toolPicker.selectedTool isKindOfClass:[PKEraserTool class]]) {
        toolPicker.selectedTool = [[PKEraserTool alloc] initWithEraserType:PKEraserTypeVector];
    }
    self.pkView.tool = toolPicker.selectedTool;
}


- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return scrollView;
}

@end
