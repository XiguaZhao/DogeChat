//
//  ImageBrowserCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/19.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatUniversal

protocol MediaBrowserCellDelegate: AnyObject {
    func livePhotoWillBegin(_ cell: MediaBrowserCell, livePhotoView: PHLivePhotoView)
    func livePhotoDidEnd(_ cell: MediaBrowserCell, livePhotoView: PHLivePhotoView)
    func singleTap(_ cell: MediaBrowserCell)
}

class MediaBrowserCell: UICollectionViewCell, PHLivePhotoViewDelegate {
    
    static let cellID = "ImageBrowserCell"
    let imageView = FLAnimatedImageView()
    let livePhotoView = PHLivePhotoView()
    let player = AVPlayer()
    var item: AVPlayerItem!
    var videoView = VideoView()
    var imagePath: String!
    var scrollView: UIScrollView!
    var messageType = MessageType.image
    var isPlaying = false {
        didSet {
            if isPlaying {
                PlayerManager.shared.playerTypes.insert(.mediaBrowser)
            } else {
                PlayerManager.shared.playerTypes.remove(.mediaBrowser)
            }
        }
    }
    var videoEnd = false
    var tap: UITapGestureRecognizer!
    weak var delegate: MediaBrowserCellDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bounds = scrollView.frame
        scrollView.maximumZoomScale = 4
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self
        contentView.addSubview(scrollView)
        imageView.contentMode = .scaleAspectFit
        livePhotoView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)
        scrollView.addSubview(livePhotoView)
        scrollView.addSubview(videoView)
        
        tap = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        self.contentView.addGestureRecognizer(tap)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapAction(_:)))
        doubleTap.numberOfTapsRequired = 2
        self.contentView.addGestureRecognizer(doubleTap)
        tap.require(toFail: doubleTap)

        livePhotoView.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(mediaDownloadFinishNoti(_:)), name: .mediaDownloadFinished, object: nil)
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] noti in
            if noti.object as? AVPlayerItem != self?.item {
                return
            }
            self?.isPlaying = false
            self?.videoEnd = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        player.replaceCurrentItem(with: nil)
        livePhotoView.stopPlayback()
        imageView.image = nil
        imageView.animatedImage = nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = contentView.frame
        imageView.frame = scrollView.frame
        livePhotoView.frame = scrollView.frame
        videoView.frame = scrollView.frame
    }

    func apply(imagePath: String) {
        self.imagePath = imagePath
        if imagePath.contains(" ") {
            messageType = .livePhoto
        } else if imagePath.hasSuffix(".mov") {
            messageType = .video
        } else {
            messageType = .image
        }
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
    }
    
    @objc func tapAction(_ ges: UITapGestureRecognizer) {
        delegate?.singleTap(self)
    }
    
    @objc func doubleTapAction(_ ges: UITapGestureRecognizer) {
        let location = ges.location(in: self.contentView)
        if messageType == .video {
            if isPlaying {
                player.pause()
            } else {
                if videoEnd {
                    player.seek(to: .zero)
                    player.play()
                    videoEnd = false
                } else {
                    player.play()
                }
            }
            isPlaying.toggle()
        } else {
            let scale: CGFloat = scrollView.zoomScale == 1 ? 2 : 1
            scrollView.setZoomScale(scale, animated: true)
            if scale != 1 {
                scrollView.zoom(to: CGRect(center: location, size: .zero), animated: true)
            }
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
            self.item = AVPlayerItem(url: localUrl)
            player.replaceCurrentItem(with: self.item)
            self.videoView.player = self.player
            self.player.play()
            activate()
            isPlaying = true
            videoEnd = false
        }
    }
    
    func makeLivePhoto() {
        if let components = imagePath?.components(separatedBy: " "), components.count > 1,
           let imageFileName = components[0].components(separatedBy: "/").last,
           let videoFileName = components[1].components(separatedBy: "/").last {
            if let localImageURL = fileURLAt(dirName: livePhotoDir, fileName: imageFileName),
               let localVideoURL = fileURLAt(dirName: livePhotoDir, fileName: videoFileName) {
                PHLivePhoto.request(withResourceFileURLs: [localImageURL, localVideoURL], placeholderImage: nil, targetSize: .zero, contentMode: .aspectFit) { livePhoto, _ in
                    if let livePhoto = livePhoto {
                        self.livePhotoView.livePhoto = livePhoto
                        self.livePhotoView.startPlayback(with: .full)
                    }
                }
            }
        }
    }
}

extension MediaBrowserCell: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        if messageType == .image {
            return imageView
        } else if messageType == .livePhoto {
            return livePhotoView
        } else if messageType == .video {
            return videoView
        } else {
            return nil
        }
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

