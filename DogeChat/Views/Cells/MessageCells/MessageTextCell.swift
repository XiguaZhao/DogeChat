//
//  MessageTextCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/28.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatNetwork
import DogeChatUniversal
import AVFoundation

let messageFontSize: CGFloat = 17

class MessageTextCell: MessageBaseCell {
    
    static let cellID = "MessageTextCell"
    static let voicePlayer = AVPlayer()
    static var voiceURL: URL?
    
    let messageLabel = Label()
    let tapGes = UITapGestureRecognizer()
    var isPlaying = false {
        didSet {
            if isPlaying {
                PlayerManager.shared.playerTypes.insert(.chatroomVoiceCell)
            } else {
                PlayerManager.shared.playerTypes.remove(.chatroomVoiceCell)
            }
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

        messageLabel.layer.masksToBounds = true
        messageLabel.textColor = .white
        messageLabel.numberOfLines = 0
        messageLabel.isUserInteractionEnabled = true
        contentView.addSubview(messageLabel)
        indicationNeighborView = messageLabel
        
        
        tapGes.addTarget(self, action: #selector(tapAction))
        messageLabel.addGestureRecognizer(tapGes)
        
        NotificationCenter.default.addObserver(self, selector: #selector(playToEnd(_:)), name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        tapGes.isEnabled = false
        isPlaying = false
        messageLabel.textAlignment = .left
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard message != nil else { return }
        if message.messageType == .text || message.messageType == .voice {
            layoutForTextMessage()
            layoutIndicatorViewAndMainView()
        } else {
            layoutForRevokeMessage()
        }
        messageLabel.layer.cornerRadius = min(messageLabel.bounds.size.height/2.0, 20)
    }
    
    override func apply(message: Message) {
        super.apply(message: message)
        if message.messageType == .text || message.messageType == .join {
            messageLabel.text = message.text
        } else if message.messageType == .voice {
            var count = message.voiceDuration
            count = min(count, 25)
            count = max(count, 3)
            let str = Array(repeating: " ", count: count).joined()
            messageLabel.text = message.messageSender == .someoneElse ? str + "\(message.voiceDuration)''" : "\(message.voiceDuration)''" + str
        }
        if message.messageSender == .ourself {
            messageLabel.backgroundColor = UIColor(red: 24/255, green: 180/255, blue: 128/255, alpha: 1.0)

        } else {
            messageLabel.backgroundColor = #colorLiteral(red: 0.09282096475, green: 0.7103053927, blue: 1, alpha: 1)
        }
        downloadVoiceIfNeeded()
    }
    
    @objc func playToEnd(_ noti: Notification) {
        if noti.object as? AVPlayerItem != self.item {
            return
        }
        isPlaying = false
        isEnd = true
    }
    
    func playVoice() {
        if AVAudioSession.sharedInstance().categoryOptions.contains(.mixWithOthers) {
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.allowBluetooth, .allowBluetoothA2DP])
        }
        if let path = message.voiceURL, let url = fileURLAt(dirName: voiceDir, fileName: path.components(separatedBy: "/").last!) {
            let player = MessageTextCell.voicePlayer
            let item = AVPlayerItem(url: url)
            self.item = item
            player.replaceCurrentItem(with: item)
            player.seek(to: .zero)
            player.play()
            MessageTextCell.voiceURL = url
            isEnd = false
            isPlaying = true
        }
    }
    
    @objc func tapAction() {
        if MessageTextCell.voiceURL == self.voiceURL {
            if isPlaying {
                MessageTextCell.voicePlayer.pause()
                isPlaying = false
            } else {
                MessageTextCell.voicePlayer.play()
                isPlaying = true
            }
            if isEnd || MessageTextCell.voicePlayer.currentItem == nil {
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
                self.delegate?.downloadProgressUpdate(progress: progress, message: captured)
            }
        }
    }
    
    func layoutForTextMessage() {
        messageLabel.textColor = .white
        messageLabel.font = UIFont(name: "Helvetica", size: message.fontSize)
        let size = messageLabel.sizeThatFits(CGSize(width: 2*(bounds.size.width/3), height: CGFloat.greatestFiniteMagnitude))
        messageLabel.frame = CGRect(x: 0, y: 0, width: size.width + 32, height: size.height + 16)
    }
    
    func layoutForRevokeMessage() {
        messageLabel.isHidden = false
        messageLabel.font = UIFont.systemFont(ofSize: 10)
        messageLabel.textColor = .lightGray
        messageLabel.backgroundColor = UIColor(red: 247/255, green: 247/255, blue: 247/255, alpha: 1.0)
        messageLabel.textAlignment = .center
        var size = messageLabel.sizeThatFits(CGSize.zero)
        size.width += 50
        size.height += 10
        let center = CGPoint(x: bounds.size.width/2, y: bounds.size.height/2.0)
        messageLabel.frame = .init(center: center, size: size)
    }
    
    func isJoinOrQuitMessage() -> Bool {
        if let words = messageLabel.text?.components(separatedBy: " ") {
            if words.count >= 2 && words[words.count - 2] == "has" && (words[words.count - 1] == "joined" || words[words.count - 1] == "quited") {
                return true
            }
        }
        return false
    }

}
