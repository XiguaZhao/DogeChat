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
    var item: AVPlayerItem? {
        videoView.item
    }
    var isPlaying: Bool = false {
        didSet {
            DispatchQueue.main.async {
                self.iconView.isHidden = self.isPlaying
            }
            if isPlaying {
                PlayerManager.shared.playerTypes.insert(.chatroomVideoCell)
            } else {
                PlayerManager.shared.playerTypes.remove(.chatroomVideoCell)
            }
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        addMainView(videoView)
        videoView.addSubview(iconView)
        
        videoView.layer.masksToBounds = true
        videoView.doubleTap.isEnabled = false
        
        iconView.mas_makeConstraints { make in
            make?.width.height().mas_equalTo()(50)
            make?.center.equalTo()(videoView)
        }
                
        addGestureForVideoView()
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] noti in
            if noti.object as? AVPlayerItem == self?.item {
                self?.isPlaying = false
            }
        }

        endDisplayBlock = { [weak self] _, _ in
            guard let self = self else { return }
            self.videoView.player?.pause()
            self.videoView.videoEnd = true
            self.isPlaying = false
        }

        resignCenterBlock = { [weak self] _, _ in
            guard let self = self else { return }
            self.videoView.player?.pause()
            self.isPlaying = false
            self.videoView.videoEnd = true
        }

        centerDisplayBlock = { [weak self] _ , _ in
            guard let self = self, let player = self.videoView.player else { return }
            if player.currentTime() == .zero || self.videoView.videoEnd {
                self.playVideo()
            }
        }

    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        videoView.item = nil
        videoView.player?.replaceCurrentItem(with: nil)
        videoView.videoEnd = false
        isPlaying = false
    }

    override func apply(message: Message) {
        super.apply(message: message)
        makeVideo()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard message != nil else { return }
        layoutImageKindView()
        layoutIndicatorViewAndMainView()
    }

    func playVideo(url: URL, playNow: Bool) {
        if self.item == nil {
            self.videoView.item = DogeChatPlayerItem(url: url)
            let player = self.videoView.player
            if player == nil {
                self.videoView.player = AVPlayer()
            }
            videoView.player?.replaceCurrentItem(with: self.item)
        }
        if playNow {
            activeSession()
            self.videoView.player?.isMuted = true
            self.videoView.player?.seek(to: .zero)
            self.videoView.player?.play()
            videoView.videoEnd = false
            isPlaying = true
        }
    }
    
    func playVideo() {
        guard let videoPath = self.message?.videoURL, let url = fileURLAt(dirName: videoDir, fileName:videoPath.components(separatedBy: "/").last!) else { return }
        self.playVideo(url: url, playNow: true)
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
        
        videoSingleTap.require(toFail: videoView.doubleTap)
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
