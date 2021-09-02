//
//  QuickTimeMov.swift
//  LoveLiver
//
//  Created by mzp on 10/10/15.
//  Modified by tako0910 on 01/24/16
//  Copyright © 2015 mzp. All rights reserved.
//

import Foundation
import AVFoundation

class QuickTimeMov : NSObject {
    fileprivate let kKeyContentIdentifier =  "com.apple.quicktime.content.identifier"
    fileprivate let kKeyStillImageTime = "com.apple.quicktime.still-image-time"
    fileprivate let kKeySpaceQuickTimeMetadata = "mdta"
    fileprivate let path : String
    fileprivate let dummyTimeRange = CMTimeRangeMake(start: CMTimeMake(value: 0, timescale: 1000), duration: CMTimeMake(value: 200, timescale: 3000))
    
    fileprivate lazy var asset : AVURLAsset = {
        let url = URL(fileURLWithPath: self.path)
        return AVURLAsset(url: url)
    }()
    
    @objc init(path : String) {
        self.path = path
    }
    
    func readAssetIdentifier() -> String? {
        for item in metadata() {
            if item.key as? String == kKeyContentIdentifier &&
                item.keySpace!.rawValue == kKeySpaceQuickTimeMetadata {
                    return item.value as? String
            }
        }
        return nil
    }
    
    func readStillImageTime() -> NSNumber? {
        if let track = track(AVMediaType.metadata.rawValue) {
            let (reader, output, _) = try! self.reader(track, audioTrack: self.track(AVMediaType.audio.rawValue), settings: nil)
            reader.startReading()
            
            while true {
                guard let buffer = output.copyNextSampleBuffer() else { return nil }
                if CMSampleBufferGetNumSamples(buffer) != 0 {
                    let group = AVTimedMetadataGroup(sampleBuffer: buffer)
                    for item in group?.items ?? [] {
                        if item.key as? String == kKeyStillImageTime &&
                            item.keySpace!.rawValue == kKeySpaceQuickTimeMetadata {
                                return item.numberValue
                        }
                    }
                }
            }
        }
        return nil
    }
    
    @objc func write(_ dest : String, assetIdentifier : String) {
        do {
            // --------------------------------------------------
            // reader for source video
            // --------------------------------------------------
            guard let track = self.track(AVMediaType.video.rawValue) else {
                print("not found video track")
                return
            }
            let audioTrack = asset.tracks(withMediaType: AVMediaType(rawValue: AVMediaType.audio.rawValue)).first!
            let (reader, output, audioOutput) = try self.reader(track, audioTrack: audioTrack,
                settings: [kCVPixelBufferPixelFormatTypeKey as String:
                    NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)])
            
            // --------------------------------------------------
            // writer for mov
            // --------------------------------------------------
            let writer = try AVAssetWriter(outputURL: URL(fileURLWithPath: dest), fileType: AVFileType.mov)
            writer.metadata = [metadataFor(assetIdentifier)]
            
            // video track
            let input = AVAssetWriterInput(mediaType: AVMediaType.video,
                outputSettings: videoSettings(track.naturalSize))
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
            audioInput.expectsMediaDataInRealTime = true
            audioInput.transform = audioTrack.preferredTransform
            input.expectsMediaDataInRealTime = true
            input.transform = track.preferredTransform
            writer.add(input)
            writer.add(audioInput)
            // metadata track
            let adapter = metadataAdapter()
            writer.add(adapter.assetWriterInput)
            
            // --------------------------------------------------
            // creating video
            // --------------------------------------------------
            writer.startWriting()
            reader.startReading()
            writer.startSession(atSourceTime: CMTime.zero)
            
            // write metadata track
            adapter.append(AVTimedMetadataGroup(items: [metadataForStillImageTime()],
                timeRange: dummyTimeRange))
            
            // write video track
            var audioDone = false
            var videoDone = false
            input.requestMediaDataWhenReady(on: DispatchQueue(label: "assetAudioWriterQueue", attributes: [])) {
                while(input.isReadyForMoreMediaData) {
                    if reader.status == .reading {
                        if let buffer = output.copyNextSampleBuffer() {
                            if !input.append(buffer) {
                                print("cannot write: \(String(describing: writer.error))")
                                reader.cancelReading()
                            }
                        }
                    } else {
                        input.markAsFinished()
                        videoDone = true
                        if audioDone {
                            writer.finishWriting() {
                                if let e = writer.error {
                                    print("cannot write: \(e)")
                                } else {
                                    print("finish writing.")
                                }
                            }
                        }
                    }
                }
            }
            audioInput.requestMediaDataWhenReady(on: DispatchQueue(label: "assetAudioWriterQueue2", attributes: [])) {
                while(audioInput.isReadyForMoreMediaData) {
                    if reader.status == .reading {
                        if let buffer = audioOutput.copyNextSampleBuffer() {
                            if !audioInput.append(buffer) {
                                print("cannot write: \(String(describing: writer.error))")
                                reader.cancelReading()
                            }
                        }
                    } else {
                        audioInput.markAsFinished()
                        audioDone = true
                        if videoDone {
                            writer.finishWriting() {
                                if let e = writer.error {
                                    print("cannot write: \(e)")
                                } else {
                                    print("finish writing.")
                                }
                            }
                        }
                    }
                }
            }

            while writer.status == .writing {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
            }
            if let e = writer.error {
                print("cannot write: \(e)")
            }
        } catch {
            print("error")
        }
    }
    
    fileprivate func metadata() -> [AVMetadataItem] {
        return asset.metadata(forFormat: AVMetadataFormat.quickTimeMetadata)
    }
    
    fileprivate func track(_ mediaType : String) -> AVAssetTrack? {
        return asset.tracks(withMediaType: AVMediaType(rawValue: mediaType)).first
    }
    
    fileprivate func reader(_ videoTrack : AVAssetTrack, audioTrack: AVAssetTrack?, settings: [String:AnyObject]?) throws -> (AVAssetReader, AVAssetReaderOutput, AVAssetReaderTrackOutput) {
        let output = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: settings)
        let audioOutput = AVAssetReaderTrackOutput(track: audioTrack!, outputSettings: nil)
        let reader = try AVAssetReader(asset: asset)
        reader.add(output)
        reader.add(audioOutput)
        return (reader, output, audioOutput)
    }
    
    fileprivate func metadataAdapter() -> AVAssetWriterInputMetadataAdaptor {
        let spec : NSDictionary = [
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as NSString:
            "\(kKeySpaceQuickTimeMetadata)/\(kKeyStillImageTime)",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as NSString:
            "com.apple.metadata.datatype.int8"]
        
        var desc : CMFormatDescription? = nil
        CMMetadataFormatDescriptionCreateWithMetadataSpecifications(allocator: kCFAllocatorDefault, metadataType: kCMMetadataFormatType_Boxed, metadataSpecifications: [spec] as CFArray, formatDescriptionOut: &desc)
        let input = AVAssetWriterInput(mediaType: AVMediaType.metadata,
            outputSettings: nil, sourceFormatHint: desc)
        return AVAssetWriterInputMetadataAdaptor(assetWriterInput: input)
    }
    
    fileprivate func videoSettings(_ size : CGSize) -> [String:AnyObject] {
        return [
            AVVideoCodecKey: AVVideoCodecType.h264 as AnyObject,
            AVVideoWidthKey: size.width as AnyObject,
            AVVideoHeightKey: size.height as AnyObject
        ]
    }
    
    fileprivate func metadataFor(_ assetIdentifier: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.key = kKeyContentIdentifier as NSCopying & NSObjectProtocol
        item.keySpace = .quickTimeMetadata
        item.value = assetIdentifier as NSCopying & NSObjectProtocol
        item.dataType = "com.apple.metadata.datatype.UTF-8"
        return item
    }
    
    fileprivate func metadataForStillImageTime() -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.key = kKeyStillImageTime as NSCopying & NSObjectProtocol
        item.keySpace = .quickTimeMetadata
        item.value = 0 as NSCopying & NSObjectProtocol
        item.dataType = "com.apple.metadata.datatype.int8"
        return item
    }
}
