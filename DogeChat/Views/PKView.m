//
//  PKView.m
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/22.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

#import "PKView.h"

@interface PKViewDelegate ()

@property (nonatomic, strong) NSArray<PKStroke *> *oldStrokes;

@end

@implementation PKView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
    }
    return self;
}


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
        if (newStroke != nil && ![self.oldStrokes containsObject:newStroke]) {
            [self.dataChangedDelegate pkView:self.pkView message:self.message addNewStroke:newStroke];
        }
    }
    
    
    self.oldStrokes = canvasView.drawing.strokes;
}

- (void)toolPickerSelectedToolDidChange:(PKToolPicker *)toolPicker {
    if ([toolPicker.selectedTool isKindOfClass:[PKEraserTool class]]) {
        toolPicker.selectedTool = [[PKEraserTool alloc] initWithEraserType:PKEraserTypeVector];
    }
    self.pkView.tool = toolPicker.selectedTool;
}


@end
