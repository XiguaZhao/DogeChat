//
//  MessageAudioCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/12/18.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatCommonDefines

class MessageAudioCell: MessageTextCell {
    
    static let voicePlayer = AVPlayer()
    static var index: Int?
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
    var isEnd = false
    weak var item: AVPlayerItem!

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
        isEnd = true
    }

    override func apply(message: Message) {
        super.apply(message: message)
        downloadVoiceIfNeeded()
    }
    
    func playVoice() {
        self.message?.isPlaying = true
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        if let path = message.voiceURL, let url = fileURLAt(dirName: voiceDir, fileName: path.components(separatedBy: "/").last!) {
            let player = Self.voicePlayer
            let item = AVPlayerItem(url: url)
            self.item = item
            player.replaceCurrentItem(with: item)
            player.seek(to: .zero)
            player.play()
            Self.index = self.indexPath.row
            isEnd = false
            Self.isPlaying = true
        }
    }
    
    @objc func tapAction() {
        playHaptic()
        if Self.index == self.indexPath.row {
            if Self.isPlaying {
                Self.voicePlayer.pause()
                Self.isPlaying = false
            } else {
                Self.voicePlayer.play()
                Self.isPlaying = true
            }
            if isEnd || Self.voicePlayer.currentItem == nil {
                playVoice()
                Self.isPlaying = true
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
            if !captured.isPlaying {
                syncOnMainThread {
                    self.messageLabel.backgroundColor = #colorLiteral(red: 0.667152524, green: 0.4650295377, blue: 1, alpha: 1)
                }
            }
        }
        if message.voiceLocalPath != nil && message.sendStatus == .fail {
            url = message.voiceLocalPath!
            block()
        } else if let _url = fileURLAt(dirName: voiceDir, fileName: self.message.voiceURL?.fileName) {
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
