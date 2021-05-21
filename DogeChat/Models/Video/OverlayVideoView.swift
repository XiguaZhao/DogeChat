//
//  OverlayVideoView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/15.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class OverlayVideoView: UIView {

    var avSession: AVCaptureSession!
    var videoOutput: AVCaptureVideoDataOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    let delegate: AVCaptureVideoDataOutputSampleBufferDelegate
    
    init(frame: CGRect, delegate: AVCaptureVideoDataOutputSampleBufferDelegate) {
        self.delegate = delegate
        super.init(frame: frame)
        prepareCapture()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func prepareCapture() {
        avSession = AVCaptureSession()
        avSession.sessionPreset = .hd1280x720
        
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        guard let inputCamera = devices.devices.first,
              let videoInput = try? AVCaptureDeviceInput(device: inputCamera) else { return }
        if avSession.canAddInput(videoInput) {
            avSession.addInput(videoInput)
        }
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey): NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        videoOutput.setSampleBufferDelegate(self.delegate, queue: DispatchQueue.global())
        
        if avSession.canAddOutput(videoOutput) {
            avSession.addOutput(videoOutput)
        }
        let connection = videoOutput.connection(with: .video)
        connection?.videoOrientation = .portrait

        previewLayer = AVCaptureVideoPreviewLayer(session: avSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        
        self.layer.insertSublayer(previewLayer, at: 0)
        avSession.startRunning()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = self.bounds
    }

}

