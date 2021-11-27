//
//  VideoViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/15.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import MetalKit

@available(iOS 13.0, *)
class VideoChatViewController: UIViewController {
    
    var mainVideoView: FriendVideoView!
    var overlayVideoView: OverlayVideoView!
    var renderer: Renderer!
    var videoProcessor = VideoProcessor()
    var username = ""
    
    var overlayWidth: CGFloat = 0;

    override func viewDidLoad() {
        super.viewDidLoad()
        overlayWidth = view.bounds.width / 3

        guard let device = MTLCreateSystemDefaultDevice() else { return }
        mainVideoView = FriendVideoView(frame: view.bounds)
        overlayVideoView = OverlayVideoView(frame: .zero, delegate: self)
        view.addSubview(mainVideoView)
        view.addSubview(overlayVideoView)
        overlayVideoView.translatesAutoresizingMaskIntoConstraints = false
        overlayVideoView.mas_makeConstraints { make in
            make?.top.equalTo()(self.view)?.offset()(20)
            make?.trailing.equalTo()(self.view)?.offset()(-20)
            make?.width.equalTo()(self.overlayWidth)
            make?.height.equalTo()(200)
        }
        
        renderer = Renderer(device: device, renderDestination: mainVideoView)
        renderer.mtkView(mainVideoView, drawableSizeWillChange: mainVideoView.bounds.size)
        mainVideoView.delegate = renderer
    }
    
    func updateRatioForOverlayVideoView(width: CGFloat, height: CGFloat) {
        DispatchQueue.main.async {
            self.overlayVideoView.mas_updateConstraints { make in
                make?.height.equalTo()(height * (width / self.overlayWidth))
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        overlayVideoView.avSession.stopRunning()
    }
    
}

@available(iOS 13.0, *)
extension VideoChatViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard output == self.overlayVideoView.videoOutput else { return }
    }
    
    func didReceiveVideoData(_ videoData: Data!) {
    }
        
}
