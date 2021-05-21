//
//  VideoViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/15.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import MetalKit
import YPTransition

@available(iOS 13.0, *)
class VideoViewController: UIViewController {
    
    var mainVideoView: MainVideoView!
    var overlayVideoView: OverlayVideoView!
    var renderer: Renderer!
    var videoProcessor = VideoProcessor()
    let encoder = HJH264Encoder()
    let decoder = HJH264Decoder()
//    var player: HJOpenGLView!
    
    var overlayWidth: CGFloat = 0;

    override func viewDidLoad() {
        super.viewDidLoad()
        overlayWidth = view.bounds.width / 3

//        guard let device = MTLCreateSystemDefaultDevice() else { return }
        mainVideoView = MainVideoView(frame: view.bounds)
//        player = HJOpenGLView(frame: view.bounds)
        overlayVideoView = OverlayVideoView(frame: .zero, delegate: self)
        view.addSubview(mainVideoView)
//        view.addSubview(player)
//        player.setupGL()
        view.addSubview(overlayVideoView)
        overlayVideoView.translatesAutoresizingMaskIntoConstraints = false
        overlayVideoView.mas_makeConstraints { make in
            make?.top.equalTo()(self.view)?.offset()(20)
            make?.trailing.equalTo()(self.view)?.offset()(-20)
            make?.width.equalTo()(self.overlayWidth)
            make?.height.equalTo()(200)
        }
        
//        renderer = Renderer(device: device, renderDestination: mainVideoView)
//        renderer.mtkView(mainVideoView, drawableSizeWillChange: mainVideoView.bounds.size)
//        mainVideoView.delegate = renderer
        WebSocketManager.shared.videoDataDelegate = self
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
extension VideoViewController: AVCaptureVideoDataOutputSampleBufferDelegate, VideoDataDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard output == self.overlayVideoView.videoOutput else { return }
        if WebSocketManagerAdapter.shared.readyToSendVideoData {
//            videoProcessor.compressAndSend(sampleBuffer, arFrame: nil) { videoData in
//                guard !videoData.isEmpty && videoData.count < 8000 else { return }
//                WebSocketManager.shared.sendVideoData(videoData)
//            }
                // 收到数据，开始编码
                [self.videoEncoder startH264EncodeWithSampleBuffer:sampleBuffer andReturnData:^(NSData *data) {
                    NSLog(@"长度:%zd", data.length);
                    _count++;
                    NSMutableData *mData = [[NSMutableData alloc] init];
                    NSData *headData = [self bytewithInt:60000];//协议头 4位 (0-4)
                    NSData *countData = [self bytewithInt:_count];//发到第几个包 4位 (4-8)
                    NSData *legnthData = [self bytewithInt:(int)data.length];//当前包的长度 4位 (8-12)
                    NSData *dataType = [self bytewithInt:1];//type 1为视频
                    [mData appendData:headData];
                    [mData appendData:countData];
                    [mData appendData:legnthData];
                    [mData appendData:dataType];
                    [mData appendData:data];
                    NSLog(@"序号[%d]视频 %lu data[%zd]",_count,(unsigned long)data.length,mData.length);
                    [sendSocket writeData:[mData copy] withTimeout:60 tag:201];
                    [self.decoder startH264DecodeWithVideoData:(char *)data.bytes andLength:(int)data.length andReturnDecodedData:^(CVPixelBufferRef pixelBuffer) {
                            [self.playView displayPixelBuffer:pixelBuffer];
                    }];
                }];
        }
    }
    
    func didReceiveVideoData(_ videoData: Data!) {
//        guard let data = videoData,
//              let videoFrameData = try? JSONDecoder().decode(VideoFrameData.self, from: data) else { return }
//        let sampleBuffer = videoFrameData.makeSampleBuffer()
//        videoProcessor.decompress(sampleBuffer) { [weak self] imageBuffer, presentationTimeStamp in
//            guard let wself = self else { return }
//            let width = CGFloat(CVPixelBufferGetWidth(imageBuffer))
//            let height = CGFloat(CVPixelBufferGetHeight(imageBuffer))
//            wself.updateRatioForOverlayVideoView(width: width, height: height)
//            wself.renderer.enqueueFrame(pixelBuffer: imageBuffer, presentationTimeStamp: presentationTimeStamp, inverseProjectionMatrix: nil, inverseViewMatrix: nil)
//        }
        self.mainVideoView.didReceive(videoData)
    }
    
    - (NSData * )bytewithInt:(int )i {
        Byte b1=i & 0xff;
        Byte b2=(i>>8) & 0xff;
        Byte b3=(i>>16) & 0xff;
        Byte b4=(i>>24) & 0xff;
        Byte byte[] = {b4,b3,b2,b1};
        NSData *data = [NSData dataWithBytes:byte length:sizeof(byte)];
        return data;
    }
    
}
