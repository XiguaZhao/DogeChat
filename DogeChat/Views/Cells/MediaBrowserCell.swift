//
//  ImageBrowserCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/19.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatCommonDefines
import AVFoundation

protocol MediaBrowserCellDelegate: AnyObject {
    func livePhotoWillBegin(_ cell: MediaBrowserCell, livePhotoView: PHLivePhotoView)
    func livePhotoDidEnd(_ cell: MediaBrowserCell, livePhotoView: PHLivePhotoView)
    func singleTap(_ cell: MediaBrowserCell)
    func mediaCellDidZoom(_cell: MediaBrowserCell)
}

class MediaBrowserCell: UICollectionViewCell, PHLivePhotoViewDelegate, VideoViewDelegate {
    
    static let cellID = "ImageBrowserCell"
    let imageView = FLAnimatedImageView()
    let livePhotoView = PHLivePhotoView()
    var videoView = VideoView()
    var imagePath: String!
    var scrollView: UIScrollView!
    var messageType = MessageType.image
    var longPress: UILongPressGestureRecognizer!
    weak var vc: UIViewController?
    var tap: UITapGestureRecognizer!
    var doubleTap: UITapGestureRecognizer!
    weak var delegate: MediaBrowserCellDelegate?
    var purpose: MediaVCPurpose = .normal
    
    let container = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bounds = scrollView.frame
        scrollView.maximumZoomScale = 4
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self
        scrollView.isDirectionalLockEnabled = true
        contentView.addSubview(scrollView)
        imageView.contentMode = .scaleAspectFit
        livePhotoView.contentMode = .scaleAspectFit
        scrollView.addSubview(container)
        container.addSubview(imageView)
        container.addSubview(livePhotoView)
        container.addSubview(videoView)
        
        videoView.delegate = self
        videoView.type = .mediaBrowser
        
        longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPress(_:)))
        self.contentView.addGestureRecognizer(longPress)
        
        tap = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        self.contentView.addGestureRecognizer(tap)
        doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapAction(_:)))
        doubleTap.numberOfTapsRequired = 2
        self.contentView.addGestureRecognizer(doubleTap)
        tap.require(toFail: doubleTap)
        tap.require(toFail: videoView.doubleTap)

        livePhotoView.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(mediaDownloadFinishNoti(_:)), name: .mediaDownloadFinished, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        videoView.player?.replaceCurrentItem(with: nil)
        livePhotoView.stopPlayback()
        imageView.image = nil
        imageView.animatedImage = nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = contentView.frame
        container.frame = contentView.frame
        if let path = self.imagePath, let size = sizeFromStr(path) {
            let targetSize = getSizeFromViewSize(self.contentView.bounds.size, animateViewSize: size)
            getView()?.frame = CGRect(center: contentView.center, size: targetSize)
        } else if self.purpose == .avatar {
            let length = min(contentView.frame.width, contentView.frame.height)
            getView()?.frame = CGRect(center: contentView.center, size: CGSize(width: length, height: length))
        } else {
            getView()?.frame = contentView.frame
        }
    }
    
    func getView() -> UIView? {
        var targetView: UIView?
        switch self.messageType {
        case .image:
            targetView = imageView
        case .livePhoto:
            targetView = livePhotoView
        case .video:
            targetView = videoView
        default: break
        }
        return targetView
    }
    
    func apply(imagePath: String) {
        self.imagePath = imagePath
        if imagePath.contains(" ") {
            messageType = .livePhoto
        } else if imagePath.hasSuffix(".mov") {
            messageType = .video
            videoView.showSliderAnimated(true, show: true, delay: 0)
        } else {
            messageType = .image
        }
        doubleTap.isEnabled = messageType != .video
        imageView.isHidden = messageType != .image
        videoView.isHidden = messageType != .video
        livePhotoView.isHidden = messageType != .livePhoto
        if messageType == .image {
            let block: (String, Data) -> Void = { [self] imagePath, data in
                if imagePath.hasSuffix(".gif") {
                    imageView.animatedImage = FLAnimatedImage(gifData: data)
                } else  {
                    imageView.image = UIImage(data: data)
                }
            }
            MediaLoader.shared.requestImage(urlStr: imagePath, type: .image, imageWidth: .original, needCache: false) { image, data, _ in
                guard self.imagePath == imagePath, let data = data else { return }
                block(imagePath, data)
            }
        } else if messageType == .livePhoto {
            makeLivePhoto()
        } else if messageType == .video {
            makeVideo()
        }
        setNeedsLayout()
    }
    
    @objc func tapAction(_ ges: UITapGestureRecognizer) {
        if messageType != .video {
            delegate?.singleTap(self)
        } else {
            videoView.showSliderAnimated(true, show: videoView.stack.alpha == 0, delay: 0)
        }
    }
        
    
    func videoView(_ videoView: VideoView, onPlay: UIButton) {
    }
    
    func videoView(_ videoView: VideoView, onPause: UIButton) {
    }
    
    func videoView(_ videoView: VideoView, onSlider: UISlider, value: Float) {
    }
    
    @objc func longPress(_ ges: UILongPressGestureRecognizer) {
        guard ges.state == .ended else { return }
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: localizedString("saveToAlbum"), style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            switch self.messageType {
            case .image:
                if self.imageView.animatedImage != nil {
                    self.requestAuth { success in
                        if success {
                            PHPhotoLibrary.shared().performChanges {
                                let request = PHAssetCreationRequest.forAsset()
                                request.addResource(with: .photo, data: self.imageView.animatedImage.data, options: nil)
                            } completionHandler: { success, error in
                                self.vc?.makeAutoAlert(message: (error == nil ? localizedString("success") : error!.localizedDescription), detail: nil, showTime: 0.3, completion: nil)
                            }
                        } else {
                            self.vc?.makeAutoAlert(message: localizedString("notAuthorized"), detail: nil, showTime: 0.5, completion: nil)
                        }
                    }
                } else if let image = self.imageView.image {
                    UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.image(image:didFinishSavingWithError:contextInfo:)), nil)
                }
            case .video:
                if let filename = self.imagePath?.fileName, let filePath = fileURLAt(dirName: videoDir, fileName: filename)?.filePath {
                    UISaveVideoAtPathToSavedPhotosAlbum(filePath, self, #selector(self.video(videoPath:didFinishSavingWithError:contextInfo:)), nil)
                }
            case .livePhoto:
                let saveBlock: (Bool) -> Void = { success in
                    if success {
                        if let (localImageURL, localVideoURL) = self.localUrlPathLivePhoto() {
                            PHPhotoLibrary.shared().performChanges {
                                let request = PHAssetCreationRequest.forAsset()
                                request.addResource(with: .photo, fileURL: localImageURL, options: nil)
                                request.addResource(with: .pairedVideo, fileURL: localVideoURL, options: nil)
                            } completionHandler: { success, error in
                                self.vc?.makeAutoAlert(message: (error == nil ? localizedString("success") : error!.localizedDescription), detail: nil, showTime: 0.3, completion: nil)
                            }
                        }
                    } else {
                        self.vc?.makeAutoAlert(message: localizedString("notAuthorized"), detail: nil, showTime: 0.5, completion: nil)
                    }
                }
                self.requestAuth { success in
                    saveBlock(success)
                }
                break
            default: break
            }
        }))
        sheet.addAction(UIAlertAction(title: localizedString("cancel"), style: .cancel, handler: nil))
        let popover = sheet.popoverPresentationController
        popover?.sourceView = self.contentView
        popover?.sourceRect = CGRect(origin: self.contentView.center, size: CGSize(width: 100, height: 100))
        popover?.permittedArrowDirections = [.down]
        self.vc?.present(sheet, animated: true, completion: nil)
    }
    
    func requestAuth(_ completion: @escaping((Bool) -> Void)) {
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite, handler: { status in
                completion(status == .authorized)
            })
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                completion(status == .authorized)
            }
        }
    }
    
    @objc func image(image: UIImage, didFinishSavingWithError error: NSError?, contextInfo:UnsafeRawPointer) {
        self.vc?.makeAutoAlert(message: (error == nil ? localizedString("success") : error!.localizedDescription), detail: nil, showTime: 0.3, completion: nil)
    }
    
    @objc func video(videoPath: String, didFinishSavingWithError error: NSError?, contextInfo:UnsafeRawPointer) {
        self.vc?.makeAutoAlert(message: (error == nil ? localizedString("success") : error!.localizedDescription), detail: nil, showTime: 0.3, completion: nil)
    }

    
    @objc func doubleTapAction(_ ges: UITapGestureRecognizer) {
        let location = ges.location(in: self.contentView)
        let scale: CGFloat = scrollView.zoomScale == 1 ? 2 : 1
        scrollView.setZoomScale(scale, animated: true)
        if scale != 1 {
            scrollView.zoom(to: CGRect(center: location, size: .zero), animated: true)
        }
    }
        
    @objc func mediaDownloadFinishNoti(_ noti: Notification) {
        guard let path = noti.object as? String, path == self.imagePath else { return }
        apply(imagePath: path)
    }
    
    func activate() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay])
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    func makeVideo() {
        if let fileName = imagePath?.components(separatedBy: "/").last,
            let localUrl = fileURLAt(dirName: videoDir, fileName: fileName) {
            videoView.item = DogeChatPlayerItem(url: localUrl)
            videoView.player = AVPlayer()
            videoView.player?.replaceCurrentItem(with: videoView.item)
            videoView.switchVideo(play: true)
            activate()
        }
    }
    
    func makeLivePhoto() {
        if let localURLs = localUrlPathLivePhoto() {
            PHLivePhoto.request(withResourceFileURLs: [localURLs.imageURL, localURLs.videoURL], placeholderImage: nil, targetSize: .zero, contentMode: .aspectFit) { livePhoto, _ in
                if let livePhoto = livePhoto {
                    self.livePhotoView.livePhoto = livePhoto
                    self.livePhotoView.startPlayback(with: .full)
                }
            }
        }
    }
    
    func localUrlPathLivePhoto() -> (imageURL: URL, videoURL: URL)? {
        if let components = imagePath?.components(separatedBy: " "), components.count > 1,
           let imageFileName = components[0].components(separatedBy: "/").last,
           let videoFileName = components[1].components(separatedBy: "/").last {
            if let localImageURL = fileURLAt(dirName: livePhotoDir, fileName: imageFileName),
               let localVideoURL = fileURLAt(dirName: livePhotoDir, fileName: videoFileName) {
                return (localImageURL, localVideoURL)
            }
        }
        return nil
    }
    
}

extension MediaBrowserCell: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return container
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        delegate?.mediaCellDidZoom(_cell: self)
    }
    
    
    func livePhotoView(_ livePhotoView: PHLivePhotoView, didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
        tap.isEnabled = true
        delegate?.livePhotoDidEnd(self, livePhotoView: livePhotoView)
    }
    
    func livePhotoView(_ livePhotoView: PHLivePhotoView, willBeginPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
        tap.isEnabled = false
        delegate?.livePhotoWillBegin(self, livePhotoView: livePhotoView)
    }
}

