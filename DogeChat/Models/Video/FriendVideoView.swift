//
//  FriendVideoView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/17.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import MetalKit

@available(iOS 13.0, *)
@objc class FriendVideoView: MTKView {
    
    var renderer: Renderer!
    @objc var processor: VideoProcessor!
    var lastWidthAndHeight: (width: CGFloat, height: CGFloat) = (0, 0)
        
    @objc func prepare() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Unable to get system default device!")
        }
        self.device = device
        self.backgroundColor = .clear
        self.colorPixelFormat = .bgra8Unorm
        self.depthStencilPixelFormat = .depth32Float_stencil8
        
        renderer = Renderer(device: device, renderDestination: self)
        renderer.mtkView(self, drawableSizeWillChange: self.bounds.size)
        self.delegate = renderer
        processor = VideoProcessor()
    }
    
    @objc func didReceiveData(_ data: Data) {
        let length = Recorder.int(with: data.subdata(in: Range(NSRange(location: 8, length: 4))!))
        let type = Recorder.int(with: data.subdata(in: Range(NSRange(location: 12, length: 4))!))
        let videoData = data.subdata(in: Range(NSRange(location: 16, length: Int(length)))!)
        if type == 1 {
            guard let frameData = try? JSONDecoder().decode(VideoFrameData.self, from: videoData) else { return }
            let sampleBuffer = frameData.makeSampleBuffer()
            self.processor.decompress(sampleBuffer) { [self] imageBuffer, presentationTimeStamp in
                let width = CGFloat(CVPixelBufferGetWidth(imageBuffer))
                let height = CGFloat(CVPixelBufferGetHeight(imageBuffer))
                DispatchQueue.main.async {
                    self.updateLayout(width: width, height: height)
                }
                self.renderer.enqueueFrame(pixelBuffer: imageBuffer, presentationTimeStamp: presentationTimeStamp)
            }
        }
    }
    
    func updateLayout(width: CGFloat, height: CGFloat) {
        guard let view = self.superview else { return }
        if lastWidthAndHeight.width == width && lastWidthAndHeight.height == height {
            return
        }
        lastWidthAndHeight = (width, height)
        let screenWidth = UIScreen.main.bounds.width
        self.frame = CGRect(x: 0, y: 0, width: screenWidth, height: screenWidth * height / width)
        self.center = view.center
    }

}
