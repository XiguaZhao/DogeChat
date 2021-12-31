//
//  MessageAudioCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/12/18.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatUniversal

class MessageAudioCell: MessageTextCell {
    
    static let voicePlayer = AVPlayer()
    static var voiceURL: URL?
    static var isPlaying = false {
        didSet {
            if isPlaying {
                PlayerManager.shared.playerTypes.insert(.chatroomVoiceCell)
            } else {
                PlayerManager.shared.playerTypes.remove(.chatroomVoiceCell)
            }
        }
    }
    
    static func audioCellID() -> String {
        return "MessageAudioCell"
    }

    let tapGes = UITapGestureRecognizer()
    var isPlaying = false {
        didSet {
            Self.isPlaying = isPlaying
        }
    }
    var isEnd = false
    weak var item: AVPlayerItem!
    var voiceURL: URL? {
        if let name = message?.voiceURL?.components(separatedBy: "/").last {
            return fileURLAt(dirName: voiceDir, fileName: name)
        }
        return nil
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        tapGes.addTarget(self, action: #selector(tapAction))
        messageLabel.addGestureRecognizer(tapGes)
        
        NotificationCenter.default.addObserver(self, selector: #selector(playToEnd(_:)), name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func playToEnd(_ noti: Notification) {
        if noti.object as? AVPlayerItem != self.item {
            return
        }
        isPlaying = false
        isEnd = true
    }

    override func apply(message: Message) {
        super.apply(message: message)
        downloadVoiceIfNeeded()
    }
    
    func playVoice() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .default, options: .duckOthers)
        if let path = message.voiceURL, let url = fileURLAt(dirName: voiceDir, fileName: path.components(separatedBy: "/").last!) {
            let player = Self.voicePlayer
            let item = AVPlayerItem(url: url)
            self.item = item
            player.replaceCurrentItem(with: item)
            player.seek(to: .zero)
            player.play()
            Self.voiceURL = url
            isEnd = false
            isPlaying = true
        }
    }
    
    @objc func tapAction() {
        playHaptic()
        if Self.voiceURL == self.voiceURL {
            if isPlaying {
                Self.voicePlayer.pause()
                isPlaying = false
            } else {
                Self.voicePlayer.play()
                isPlaying = true
            }
            if isEnd || Self.voicePlayer.currentItem == nil {
                playVoice()
                isPlaying = true
            }
        } else {
            playVoice()
        }
    }
    
    func downloadVoiceIfNeeded() {
        var url: URL?
        guard let captured = self.message, message.messageType == .voice else { return }
        let block: () -> Void = { [weak self] in
            guard let self = self, captured == self.message, let url = url else { return }
            self.message.videoLocalPath = url
            self.tapGes.isEnabled = true
            syncOnMainThread {
                self.messageLabel.backgroundColor = #colorLiteral(red: 0.667152524, green: 0.4650295377, blue: 1, alpha: 1)
            }
        }
        if message.voiceLocalPath != nil && message.sendStatus == .fail {
            url = message.voiceLocalPath!
            block()
        } else if let _url = fileURLAt(dirName: voiceDir, fileName: self.message.voiceURL!.components(separatedBy: "/").last!) {
            url = _url
            block()
        } else {
            MediaLoader.shared.requestImage(urlStr: message.voiceURL!, type: .voice, cookie: manager?.cookie, syncIfCan: true) { [weak self] _, _, localURL in
                self?.delegate?.downloadSuccess(self, message: captured)
            } progress: { progress in
                self.delegate?.downloadProgressUpdate(progress: progress, messages: [captured])
            }
        }
    }
    

}
