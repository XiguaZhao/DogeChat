//
//  EmojiCollectionViewCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/2/24.
//  Copyright © 2021 Xiguang Zhao. All rights reserved.
//

import UIKit
import DogeChatNetwork
import DACircularProgress

protocol EmojiSelectCellLongPressDelegate: AnyObject {
    func didLongPressEmojiCell(_ cell: EmojiCollectionViewCell)
    func updateDownloadProgress(_ cell: EmojiCollectionViewCell, progress: Double, path: String)
}

class EmojiCollectionViewCell: DogeChatBaseCollectionViewCell {
    
    static let cellID = "EmojiCollectionViewCell"
    let emojiView = UIImageView()
    let imageDownloader = SDWebImageManager.shared
    var url: URL?
    weak var delegate: EmojiSelectCellLongPressDelegate?
    var indexPath: IndexPath!
    var path: String!
    let progress = DACircularProgressView()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let offset: CGFloat = 5
        let size = contentView.frame.size
        emojiView.frame = CGRect(x: offset, y: offset, width: size.width-2*offset, height: size.height-2*offset)
        progress.center = self.contentView.center
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(emojiView)
        emojiView.contentMode = .scaleAspectFill
        emojiView.layer.cornerRadius = 5
        emojiView.layer.masksToBounds = true
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction(_:)))
        emojiView.isUserInteractionEnabled = true
        if isMac() {
            longPress.isEnabled = false
        }
        emojiView.addGestureRecognizer(longPress)
        
        contentView.addSubview(progress)
        progress.isHidden = true
        progress.thicknessRatio = 0.3
        progress.progressTintColor = UIColor(named: "progressCircle")
        progress.bounds = CGRect(x: 0, y: 0, width: 25, height: 25)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        emojiView.image = nil
        progress.isHidden = true
    }
    
    @objc func longPressAction(_ ges: UILongPressGestureRecognizer) {
        delegate?.didLongPressEmojiCell(self)
    }
    
    
    func displayEmoji(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        self.url = url
        let capturedUrl = url
        MediaLoader.shared.requestImage(urlStr: urlString, type: .image, needStaticGif: true, completion: { [weak self] image, data, _ in
            guard let self = self, capturedUrl == self.url else { return }
            if let data = data {
                self.emojiView.image = UIImage(data: data)
            }
        }) { progress in
            if self.url == capturedUrl {
                self.delegate?.updateDownloadProgress(self, progress: progress, path: urlString)
                self.progress.isHidden = progress >= 1
                self.progress.setProgress(progress, animated: false)
            }
        }
    }
    
}

