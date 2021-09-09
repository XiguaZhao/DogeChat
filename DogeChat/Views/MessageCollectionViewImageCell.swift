//
//  MessageCollectionViewImageCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/28.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatNetwork
import DogeChatUniversal
import PhotosUI

class MessageCollectionViewImageCell: MessageCollectionViewBaseCell, PHLivePhotoViewDelegate {
    
    static let cellID = "MessageCollectionViewImageCell"
    
    var animatedImageView: FLAnimatedImageView!
    var livePhotoView = PHLivePhotoView()
    let imageDownloader = SDWebImageManager.shared
    let livePhotoBadgeView = UIImageView()
    let player = AVPlayer()
    var item: AVPlayerItem!
    var videoView = VideoView()
    var videoEnd = false
    var isPlaying = false
    var isGif: Bool {
        guard let url = message.imageURL else {
            return false
        }
        return url.hasSuffix(".gif")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        animatedImageView = FLAnimatedImageView()
        animatedImageView.layer.masksToBounds = true
        animatedImageView.contentMode = .scaleAspectFit
        contentView.addSubview(animatedImageView)
        contentView.addSubview(livePhotoView)
        contentView.addSubview(videoView)
        videoView.layer.masksToBounds = true
        livePhotoView.layer.masksToBounds = true
        livePhotoView.addSubview(livePhotoBadgeView)
        livePhotoBadgeView.image = PHLivePhotoView.livePhotoBadgeImage(options: .overContent)
        livePhotoBadgeView.mas_makeConstraints { [weak self] make in
            make?.leading.top().equalTo()(self?.livePhotoView)?.offset()(5)
        }
        livePhotoView.mas_makeConstraints { [weak self] make in
            make?.edges.equalTo()(self?.animatedImageView)
        }
        livePhotoView.delegate = self
        videoView.mas_makeConstraints { [weak self] make in
            make?.edges.equalTo()(self?.animatedImageView)
        }
        addGestureForImageView()
        addGestureForVideoView()
        
        NotificationCenter.default.addObserver(self, selector: #selector(playToEnd(_:)), name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        endDisplayBlock = { [weak self] _, _ in
            guard let self = self else { return }
            self.livePhotoView.stopPlayback()
            self.player.pause()
            self.videoEnd = true
        }
        resignCenterBlock = { [weak self] _, _ in
            guard let self = self else { return }
            self.livePhotoView.stopPlayback()
            self.player.pause()
            self.videoEnd = true
        }
        centerDisplayBlock = { [weak player, weak self] _ , _ in
            guard let self = self, let player = player else { return }
            self.livePhotoView.startPlayback(with: .full)
            if player.currentTime() == .zero || self.videoEnd {
                self.playVideo()
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        animatedImageView.image = nil
        animatedImageView.animatedImage = nil
        livePhotoView.livePhoto = nil
        item = nil
        player.replaceCurrentItem(with: nil)
        videoEnd = false
        isPlaying = false
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard message != nil else { return }
        layoutImageView()
        indicationNeighborView = animatedImageView
        layoutIndicatorViewAndMainView()
    }
    
    override func apply(message: Message) {
        super.apply(message: message)
        livePhotoView.isHidden = !(message.messageType == .livePhoto)
        animatedImageView.isHidden = (message.messageType == .livePhoto) || (message.messageType == .video)
        videoView.isHidden = !(message.messageType == .video)
        if message.messageType == .livePhoto {
            makeLivePhoto()
        } else if message.messageType == .video {
            makeVideo()
        }
    }
    
    func loadImageIfNeeded() {
        if message.messageType == .image {
            downloadImageIfNeeded()
        }
    }
    
    func cleanAnimatedImageView() {
        self.animatedImageView.animatedImage = nil
        self.animatedImageView.image = nil
    }
    
    func deactiveSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    func activeSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: PlayerManager.shared.isMute ? .mixWithOthers : .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    func playVideo() {
        guard let videoPath = self.message?.videoURL, let url = fileURLAt(dirName: videoDir, fileName:videoPath.components(separatedBy: "/").last!) else { return }
        self.playVideo(url: url, playNow: true)
    }
    
    func playVideo(url: URL, playNow: Bool) {
        if self.item == nil {
            self.item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: self.item)
            self.videoView.player = self.player
        }
        if playNow {
            activeSession()
            self.player.isMuted = PlayerManager.shared.isMute
            self.player.seek(to: .zero)
            self.player.play()
            videoEnd = false
            isPlaying = true
        }
    }
    
    @objc func playToEnd(_ noti: Notification) {
        if let item = noti.object as? AVPlayerItem, item == self.item {
            self.videoEnd = true
            isPlaying = false
        }
    }
    
    func makeVideo() {
        var url: URL?
        let captured = self.message
        let block: (Bool) -> Void = { [weak self] playNow in
            guard let self = self, captured == self.message, let url = url else { return }
            self.message.videoLocalPath = url
            self.playVideo(url: url, playNow: playNow)
        }
        if message.videoLocalPath != nil && message.sendStatus == .fail {
            url = message.videoLocalPath!
            block(true)
        } else if let _url = fileURLAt(dirName: videoDir, fileName: self.message.videoURL!.components(separatedBy: "/").last!) {
            url = _url
            block(false)
        } else {
            let fileName = self.message.videoURL!.components(separatedBy: "/").last!
            let completion: (URLSessionTask, Any?) -> Void = { task ,data in
                guard let data = data as? Data else { return }
                saveFileToDisk(dirName: videoDir, fileName: fileName, data: data)
                url = fileURLAt(dirName: videoDir, fileName: fileName)
                block(true)
                captured?.isDownloading = true
            }
            if !message.isDownloading {
                message.isDownloading = true
                session.get(url_pre + message.videoURL!, parameters: nil, headers: ["Cookie": "SESSION="+cookie], progress: { [weak self] progress in
                    self?.delegate?.downloadProgressUpdate(progress: progress, message: captured!)
                }, success: { task, data in
                    completion(task, data)
                    print("videoDone")
                }) { task, error in
                    print(error)
                }
            }
        }
    }
    
    func playLivePhoto() {
        self.activeSession()
        self.livePhotoView.isMuted = false
        self.livePhotoView.startPlayback(with: .full)
    }
    
    func makeLivePhoto() {
        let capturedMessage = message
        let block: (PHLivePhoto, Bool) -> Void = { [weak self] livePhoto, playNow in
            guard let self = self else { return }
            guard capturedMessage == self.message else { return }
            syncOnMainThread {
                self.livePhotoView.livePhoto = livePhoto
                if playNow {
                    self.playLivePhoto()
                }
            }
        }
        let size = MessageCollectionViewBaseCell.sizeForImageOrVideo(message)
        let livePhotoLoadBlock: (URL, URL, Bool) -> Void = { localImageURL, localVideoURL, playNow in
            let width = AppDelegate.shared.widthFor(side: .right) * 0.5
            DispatchQueue.global().async {
                PHLivePhoto.request(withResourceFileURLs: [
                                        localImageURL, localVideoURL]
                                    , placeholderImage: nil, targetSize: size == nil ? .zero : CGSize(width: width, height: width / size!.width * size!.height), contentMode: .aspectFit) { live, info in
                    if let livePhoto = live, info[PHLivePhotoInfoErrorKey] == nil {
                        if let degrade = info[PHLivePhotoInfoIsDegradedKey] as? Int, degrade == 1 {
                            return
                        } else if let cancel = info[PHLivePhotoInfoCancelledKey] as? Int, cancel == 1 {
                            return
                        } else {
                            block(livePhoto, playNow)
                        }
                    }
                }
            }
        }
        let imageName = message.imageURL!.components(separatedBy: "/").last!
        let videoName = message.videoURL!.components(separatedBy: "/").last!
        if let live = message.livePhoto as? PHLivePhoto, message.sendStatus == .fail {
            block(live, false)
        } else if let localImageURL = fileURLAt(dirName: livePhotoDir, fileName: imageName), let localVideoURL = fileURLAt(dirName: livePhotoDir, fileName: videoName) {
            livePhotoLoadBlock(localImageURL, localVideoURL, false)
        } else {
            let imageURL = URL(string: url_pre + message.imageURL!)!
            let videoURL = URL(string: url_pre + message.videoURL!)!
            let completion: (URLSessionTask, Any?) -> Void = { task ,videoData in
                guard let videoData = videoData as? Data else {
                    return
                }
                saveFileToDisk(dirName: livePhotoDir, fileName: videoName, data: videoData)
                if let localImageURL = fileURLAt(dirName: livePhotoDir, fileName: imageName),
                   let localVideoURL = fileURLAt(dirName: livePhotoDir, fileName: videoName) {
                    livePhotoLoadBlock(localImageURL, localVideoURL, true)
                }
                capturedMessage?.isDownloading = false
            }
            if !message.isDownloading {
                message.isDownloading = true
                session.get(imageURL.absoluteString, parameters: nil, headers: ["Cookie": "SESSION="+cookie], progress: nil, success: { task, data in
                    guard let data = data as? Data else { return }
                    print("liveImageDone")
                    saveFileToDisk(dirName: livePhotoDir, fileName: imageName, data: data)
                    session.get(videoURL.absoluteString, parameters: nil, headers: ["Cookie": "SESSION="+self.cookie], progress: { [weak self] progress in
                        self?.delegate?.downloadProgressUpdate(progress: progress, message: capturedMessage!)
                    }, success: { task, videoData in
                        completion(task, videoData)
                        print("liveVideoDone")
                    }, failure: nil)
                }, failure: nil)
            }
        }
    }
    
    func addGestureForImageView() {
        animatedImageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        animatedImageView.addGestureRecognizer(tap)
    }
    
    func addGestureForVideoView() {
        videoView.isUserInteractionEnabled = true
        let videoSingleTap = UITapGestureRecognizer(target: self, action: #selector(videoSingleTap(_:)))
        videoView.addGestureRecognizer(videoSingleTap)
        
        let videoDoubleTap = UITapGestureRecognizer(target: self, action: #selector(videoDoubleTap(_:)))
        videoDoubleTap.numberOfTapsRequired = 2
        videoView.addGestureRecognizer(videoDoubleTap)
        videoSingleTap.require(toFail: videoDoubleTap)
    }
    
    @objc func videoSingleTap(_ tap: UITapGestureRecognizer) {
        PlayerManager.shared.isMute.toggle()
        activeSession()
        player.isMuted.toggle()
    }
    
    @objc func videoDoubleTap(_ tap: UITapGestureRecognizer) {
        if isPlaying {
            player.pause()
        } else {
            if videoEnd {
                playVideo()
            } else {
                player.play()
            }
        }
        isPlaying.toggle()
    }
    
    @objc func imageTapped() {
        delegate?.imageViewTapped(self, imageView: animatedImageView, path: message.imageLocalPath?.absoluteString ?? message.imageURL ?? "", isAvatar: false)
    }
    
    func layoutImageView() {
        if message.imageSize == .zero {
            animatedImageView.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
            return
        }
        let maxSize = CGSize(width: 2*(AppDelegate.shared.widthFor(side: .right)/3), height: CGFloat.greatestFiniteMagnitude)
        let nameHeight = message.messageSender == .ourself ? 0 : (MessageCollectionViewBaseCell.height(forText: message.senderUsername, fontSize: 10, maxSize: maxSize) + 4 )
        let height = contentView.bounds.height - 30 - nameHeight
        let width = message.imageSize.width * height / message.imageSize.height
        animatedImageView.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        animatedImageView.layer.cornerRadius = min(width, height) / 12
        livePhotoView.layer.cornerRadius = animatedImageView.layer.cornerRadius
        videoView.layer.cornerRadius = animatedImageView.layer.cornerRadius
    }
    
    func downloadImageIfNeeded() {
        guard var imageUrl = message.imageURL else { return }
        if let local = message.imageLocalPath {
            imageUrl = local.absoluteString
        }
        if imageUrl.hasPrefix("file://") {
            DispatchQueue.global().async {
                if let imageUrl = WebSocketManager.shared.messageManager.imageDict[self.message.uuid] as? URL{
                    guard let data = try? Data(contentsOf: imageUrl) else { return }
                    self.cache.setObject(data as NSData, forKey: self.message.imageURL! as NSString)
                    DispatchQueue.main.async {
                        if self.isGif {
                            self.animatedImageView.animatedImage = FLAnimatedImage(gifData: data)
                        } else {
                            guard let image = UIImage(data: data) else { return }
                            self.animatedImageView.image = image
                        }
                    }
                }
            }
            return
        }
        // 接下来进入下载操作
        let capturedMessage = message
        if let data = cache.object(forKey: imageUrl as NSString) {
            if !isGif {
                self.animatedImageView.image = UIImage(data: data as Data)
                layoutIfNeeded()
                return
            } else {
                let animatedImage = FLAnimatedImage(gifData: data as Data)
                if animatedImage != nil {
                    self.animatedImageView.animatedImage = animatedImage
                    layoutIfNeeded()
                    return
                }
            }
        }
        
        imageDownloader.loadImage(with: URL(string: imageUrl), options: [.avoidDecodeImage, .allowInvalidSSLCertificates]) { [weak self] (received, total, url) in
            guard let self = self, capturedMessage == self.message else { return }
            let progress = Progress()
            progress.totalUnitCount = Int64(total)
            progress.completedUnitCount = Int64(received)
            self.delegate?.downloadProgressUpdate(progress: progress, message: capturedMessage!)
            
        } completed: { [self] (image, data, error, cacheType, finished, url) in
            guard let capturedMessage = capturedMessage, capturedMessage.imageURL == message.imageURL else {
                return
            }
            if !isGif, let image = image { // is photo
                let compressed = WebSocketManager.shared.messageManager.compressEmojis(image)
                animatedImageView.image = UIImage(data: compressed)
                cache.setObject(compressed as NSData, forKey: imageUrl as NSString)
            } else { // gif图处理
                animatedImageView.animatedImage = FLAnimatedImage(gifData: data)
                if let data = data {
                    cache.setObject(data as NSData, forKey: imageUrl as NSString)
                }
            }
            layoutIfNeeded()
            capturedMessage.sendStatus = .success
        }
    }


    func livePhotoView(_ livePhotoView: PHLivePhotoView, willBeginPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
    }
    
    func livePhotoView(_ livePhotoView: PHLivePhotoView, didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
    }
    

}
