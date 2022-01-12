//
//  MessageVideoCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/11/19.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatUniversal
import DogeChatCommonDefines

class MessageVideoCell: MessageImageKindCell {
    
    static let cellID = "MessageVideoCell"

    let videoView = VideoView()
    lazy var iconView: UIImageView = {
        if #available(iOS 13, *) {
            return UIImageView(image: UIImage(systemName: "play.circle.fill"))
        } else {
            return UIImageView(image: UIImage(named: "bofang"))
        }
    }()
    var videoEnd = false
    let player = AVPlayer()
    var item: AVPlayerItem!
    var isPlaying = false {
        didSet {
            DispatchQueue.main.async {
                self.iconView.isHidden = self.isPlaying
            }
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(videoView)
        videoView.addSubview(iconView)
        indicationNeighborView = videoView
        
        videoView.layer.masksToBounds = true
        
        iconView.mas_makeConstraints { make in
            make?.width.height().mas_equalTo()(50)
            make?.center.equalTo()(videoView)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(playToEnd(_:)), name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        addGestureForVideoView()

        endDisplayBlock = { [weak self] _, _ in
            guard let self = self else { return }
            self.player.pause()
            self.videoEnd = true
            self.isPlaying = false
        }

        resignCenterBlock = { [weak self] _, _ in
            guard let self = self else { return }
            self.player.pause()
            self.isPlaying = false
            self.videoEnd = true
        }

        centerDisplayBlock = { [weak player, weak self] _ , _ in
            guard let self = self, let player = player else { return }
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
        item = nil
        player.replaceCurrentItem(with: nil)
        videoEnd = false
        isPlaying = false
    }

    override func apply(message: Message) {
        super.apply(message: message)
        makeVideo()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard message != nil else { return }
        layoutImageKindView(videoView)
        layoutIndicatorViewAndMainView()
    }

    func playVideo(url: URL, playNow: Bool) {
        if self.item == nil {
            self.item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: self.item)
            self.videoView.player = self.player
        }
        if playNow {
            activeSession()
            self.player.isMuted = true
            self.player.seek(to: .zero)
            self.player.play()
            videoEnd = false
            isPlaying = true
        }
    }
    
    func playVideo() {
        guard let videoPath = self.message?.videoURL, let url = fileURLAt(dirName: videoDir, fileName:videoPath.components(separatedBy: "/").last!) else { return }
        self.playVideo(url: url, playNow: true)
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
        } else if let fileName = self.message?.videoURL?.fileName, let _url = fileURLAt(dirName: videoDir, fileName: fileName) {
            url = _url
            block(false)
        } else {
            MediaLoader.shared.requestImage(urlStr: url_pre + message.videoURL!, type: .video, cookie: cookie, syncIfCan: true) { [weak self] _, _, localURL in
                print("videoDone")
                self?.delegate?.downloadSuccess(self, message: captured!)
                NotificationCenter.default.post(name: .mediaDownloadFinished, object: captured?.text, userInfo: nil)
            } progress: { [weak self] progress in
                self?.delegate?.downloadProgressUpdate(progress: progress, messages: [captured!])
            }
        }
    }

    func addGestureForVideoView() {
        videoView.isUserInteractionEnabled = true
        let videoSingleTap = UITapGestureRecognizer(target: self, action: #selector(videoTapped))
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
    
    @objc func videoTapped() {
        delegate?.mediaViewTapped(self, path: message.text, isAvatar: false)
    }
    
    func activeSession() {
        if !PlayerManager.shared.isPlaying {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .allowBluetooth)
        }
    }

    
}
