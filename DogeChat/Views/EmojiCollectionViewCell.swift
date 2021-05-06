//
//  EmojiCollectionViewCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/2/24.
//  Copyright © 2021 Xiguang Zhao. All rights reserved.
//

import UIKit
import YPTransition

class EmojiCollectionViewCell: UICollectionViewCell {
    
    static let cellID = "EmojiCollectionViewCell"
    let emojiView = UIImageView()
    let imageDownloader = SDWebImageManager.shared
    var url: URL?
    var cache: NSCache<NSString, NSData>?
    weak var delegate: EmojiViewDelegate?
    var indexPath: IndexPath!
    var path: String!
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let offset: CGFloat = 5
        let size = contentView.frame.size
        emojiView.frame = CGRect(x: offset, y: offset, width: size.width-2*offset, height: size.height-2*offset)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(emojiView)
        emojiView.contentMode = .scaleAspectFit
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
    
    @objc func tapTwice(_ ges: UITapGestureRecognizer) {
        delegate?.deleteEmoji?(cell: self)
    }
        
    func displayEmoji(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        self.url = url
        let capturedUrl = url
        if let cache = cache, let data = cache.object(forKey: urlString as NSString) {
            self.emojiView.image = UIImage(data: data as Data)
            return
        }
        DispatchQueue.global().async {
            self.imageDownloader.loadImage(with: url, options: .avoidDecodeImage) { (received, total, url) in

            } completed: { (image, data, error, cacheType, finished, url) in
                guard capturedUrl == self.url else { return }
                self.layoutIfNeeded()
                DispatchQueue.global().async {
                    if let image = image {
                        let compressed = WebSocketManager.shared.compressEmojis(image)
                        DispatchQueue.main.async {
                            self.emojiView.image = UIImage(data: compressed)
                        }
                        self.cache?.setObject(compressed as NSData, forKey: urlString as NSString
                        )
                    }
                }
            }
        }
    }
    
}

