//
//  PKView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/3.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import Foundation
import PencilKit
import DogeChatCommonDefines

@available(iOS 13.0, *)
protocol PKViewChangeDelegate: AnyObject {
    
    func pkView(pkView: PKCanvasView, message: Message?, newStroke: Any)
    func pkView(pkView: PKCanvasView, message: Message?, deleteStrokesIndex: [Int])
    func pkViewDidFinishDrawing(pkView: PKCanvasView, message: Message?)
    func pkViewDidCancelDrawing(pkView: PKCanvasView, message: Message?)

}

protocol PKViewAutoOffsetDelegate: AnyObject {
    
    func shouldAutoOffset(_ should: Bool)
    
}

@available(iOS 13.0, *)
class PKViewDelegate: NSObject, PKCanvasViewDelegate, PKToolPickerObserver {
    
    weak var pkView: PKCanvasView?
    weak var dataChangeDelegate: PKViewChangeDelegate?
    weak var autoOffsetDelegate: PKViewAutoOffsetDelegate?
    var message: Message?
    private var sendDeletes = false
    
    
    func autoOffset() {
        guard let pkView = pkView else {
            return
        }
        var originalOffset = pkView.contentOffset
        originalOffset.x += 0.6 * pkView.bounds.width
        originalOffset.x = min(originalOffset.x, pkView.contentSize.width - pkView.bounds.width)
        pkView.setContentOffset(originalOffset, animated: true)
    }
    
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        if #available(iOS 14, *) {
            if canvasView.tool is PKEraserTool {
                if !sendDeletes { return }
            } else if canvasView.tool is PKInkingTool {
                let newStrokes = canvasView.drawing.strokes
                guard let newStroke = newStrokes.last else { return }
                self.dataChangeDelegate?.pkView(pkView: canvasView, message: self.message, newStroke: newStroke)
                let bounds = PKDrawing(strokes: [newStroke]).bounds
                var shouldAutoOffset = false
                if bounds.maxX > canvasView.contentOffset.x + canvasView.bounds.width * 0.7 {
                    shouldAutoOffset = true
                }
                self.autoOffsetDelegate?.shouldAutoOffset(shouldAutoOffset)
            }
        }
    }
    
    func toolPickerSelectedToolDidChange(_ toolPicker: PKToolPicker) {
        if toolPicker.selectedTool is PKEraserTool && (toolPicker.selectedTool as! PKEraserTool).eraserType != .vector {
            toolPicker.selectedTool = PKEraserTool.init(.vector)
        }
        self.pkView?.tool = toolPicker.selectedTool
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scrollView
    }
    
}
