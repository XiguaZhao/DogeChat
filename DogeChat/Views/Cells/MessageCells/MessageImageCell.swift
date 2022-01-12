//
//  MessageImageCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/28.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatNetwork
import DogeChatUniversal
import DogeChatCommonDefines

class MessageImageCell: MessageImageKindCell {
    
    static let cellID = "MessageImageCell"
    
    var animatedImageView: FLAnimatedImageView!
    var isGif: Bool {
        let url = message.imageURL ?? message.imageLocalPath?.absoluteString ?? ""
        return url.hasSuffix(".gif")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        animatedImageView = FLAnimatedImageView()
        animatedImageView.layer.masksToBounds = true
        animatedImageView.contentMode = .scaleAspectFit
        contentView.addSubview(animatedImageView)
        addGestureForImageView()
        indicationNeighborView = animatedImageView
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        animatedImageView.image = nil
        animatedImageView.animatedImage = nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard message != nil else { return }
        layoutImageView()
        layoutIndicatorViewAndMainView()
    }
    
    override func apply(message: Message) {
        super.apply(message: message)
        loadImageIfNeeded()
        self.setNeedsLayout()
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
    
    func addGestureForImageView() {
        animatedImageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        animatedImageView.addGestureRecognizer(tap)
    }
        
    
    @objc func imageTapped() {
        delegate?.mediaViewTapped(self, path: message.text, isAvatar: false)
    }
    
    func layoutImageView() {
        layoutImageKindView(animatedImageView)
    }
    
    func downloadImageIfNeeded() {
        guard let imageUrl = message.imageURL ?? message.imageLocalPath?.absoluteString else { return }
        if imageUrl.hasPrefix("file://") {
            DispatchQueue.global().async {
                if let imageUrl = URL(string: imageUrl) {
                    guard let data = try? Data(contentsOf: imageUrl) else { return }
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
        let capturedMessage = message
        // 接下来进入下载操作
        MediaLoader.shared.requestImage(urlStr: imageUrl, type: .image, syncIfCan: message.syncGetMedia, imageWidth: isGif ? .original : .width300) { [self] image, data, _ in
                guard let capturedMessage = capturedMessage, capturedMessage.imageURL == message.imageURL, let data = data else {
                    return
                }
                if !isGif { // is photo
                    animatedImageView.image = UIImage(data: data)
                } else { // gif图处理
                    animatedImageView.animatedImage = FLAnimatedImage(gifData: data)
                }
                layoutIfNeeded()
                capturedMessage.sendStatus = .success
                NotificationCenter.default.post(name: .mediaDownloadFinished, object: capturedMessage.text, userInfo: nil)
            } progress: { progress in
                self.delegate?.downloadProgressUpdate(progress: progress, messages: [capturedMessage!])
            }
        message.syncGetMedia = false
        
    }
    

}
