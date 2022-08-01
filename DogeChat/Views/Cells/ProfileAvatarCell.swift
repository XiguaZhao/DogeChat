//
//  ProfileAvatarCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/12/19.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import FLAnimatedImage

class ProfileAvatarCell: DogeChatTableViewCell {
    
    let cellHeight: CGFloat = 220
    static let cellID = "profileAvatarCell"

    let avatarImageView = FLAnimatedImageView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        let width: CGFloat = 180

        contentView.addSubview(avatarImageView)
        
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.layer.masksToBounds = true
        avatarImageView.layer.cornerRadius = width / 2
        avatarImageView.mas_makeConstraints { make in
            make?.width.height().mas_equalTo()(width)
            make?.center.equalTo()(self.contentView)
            make?.top.equalTo()(self.contentView)?.offset()((cellHeight - width) / 2)
            make?.bottom.equalTo()(self.contentView)?.offset()(-(cellHeight - width) / 2)
        }
                
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func apply(url: String?) {
        guard let url = url else {
            return
        }
        MediaLoader.shared.requestImage(urlStr: url, type: .sticker, cookie: nil, syncIfCan: false, imageWidth: .original, needStaticGif: false, needCache: false, completion: { [weak self] image, data, _ in
            guard let data = data else { return }
            if url.isGif {
                self?.avatarImageView.animatedImage = FLAnimatedImage(gifData: data)
            } else {
                self?.avatarImageView.image = UIImage(data: data)
            }
        }, progress: nil)
    }
    
}
