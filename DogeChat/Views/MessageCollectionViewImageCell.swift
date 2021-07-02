//
//  MessageCollectionViewImageCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/28.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import YPTransition
import DogeChatUniversal

class MessageCollectionViewImageCell: MessageCollectionViewBaseCell {
    
    static let cellID = "MessageCollectionViewImageCell"
    
    var animatedImageView: FLAnimatedImageView!
    let imageDownloader = SDWebImageManager.shared
    var isGif: Bool {
        guard let url = message.imageURL else {
            return false
        }
        return url.hasSuffix(".gif")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        animatedImageView = FLAnimatedImageView()
        
        animatedImageView.contentMode = .scaleAspectFit
        contentView.addSubview(animatedImageView)
        addGestureForImageView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        animatedImageView.image = nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutImageView()
        indicationNeighborView = animatedImageView
        layoutIndicatorViewAndMainView()
    }
    
    override func apply(message: Message) {
        super.apply(message: message)
    }
    
    func addGestureForImageView() {
        animatedImageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        animatedImageView.addGestureRecognizer(tap)
    }
    
    @objc func imageTapped() {
        delegate?.imageViewTapped(self, imageView: animatedImageView, path: message.imageURL ?? "", isAvatar: false)
    }
    
    func layoutImageView() {
        animatedImageView.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
    }
    
    func downloadImageIfNeeded() {
        guard let imageUrl = message.imageURL else { return }
        if imageUrl.hasPrefix("file://") {
            DispatchQueue.global().async {
                if let imageUrl = WebSocketManager.shared.messageManager.imageDict[self.message.uuid] as? URL{
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
        
        imageDownloader.loadImage(with: URL(string: imageUrl), options: .avoidDecodeImage) { (received, total, url) in
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


}
