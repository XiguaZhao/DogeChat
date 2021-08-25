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

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        animatedImageView = FLAnimatedImageView()
        animatedImageView.layer.masksToBounds = true
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
        animatedImageView.animatedImage = nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutImageView()
        indicationNeighborView = animatedImageView
        layoutIndicatorViewAndMainView()
    }
    
    override func apply(message: Message) {
        super.apply(message: message)
        downloadImageIfNeeded()
    }
    
    func addGestureForImageView() {
        animatedImageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        animatedImageView.addGestureRecognizer(tap)
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
        
        imageDownloader.loadImage(with: URL(string: imageUrl), options: [.avoidDecodeImage, .allowInvalidSSLCertificates]) { (received, total, url) in
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
