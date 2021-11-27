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
    
    override init(frame: CGRect, device: MTLDevice?) {
        let width = UIScreen.main.bounds.width
        let center = UIScreen.main.bounds.center
        let height = 640 * width / 360
        super.init(frame: CGRect(center: center, size: CGSize(width: width, height: height)), device: nil)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
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
        let nsdata = data as NSData
        _ = Recorder.int(with: nsdata.subdata(with: NSRange(location: 0, length: 4)))
        _ = Recorder.int(with: nsdata.subdata(with: NSRange(location: 4, length: 4)))
        let length = Recorder.int(with: nsdata.subdata(with: NSRange(location: 8, length: 4)))
        let type = Recorder.int(with: nsdata.subdata(with: NSRange(location: 12, length: 4)))
        let videoData = nsdata.subdata(with: NSRange(location: 16, length: Int(length)))
        if type == 1 {
            guard let frameData = try? JSONDecoder().decode(VideoFrameData.self, from: videoData) else { return }
            let sampleBuffer = frameData.makeSampleBuffer()
            self.processor.decompress(sampleBuffer) { [self] imageBuffer, presentationTimeStamp in
                let width = CGFloat(CVPixelBufferGetWidth(imageBuffer))
                let height = CGFloat(CVPixelBufferGetHeight(imageBuffer))
                DispatchQueue.main.async {
                    self.updateLayout(width: width, height: height)
                }
                self.renderer.enqueueFrame(pixelBuffer: imageBuffer, presentationTimeStamp: presentationTimeStamp, inverseProjectionMatrix: nil, inverseViewMatrix: nil)
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
