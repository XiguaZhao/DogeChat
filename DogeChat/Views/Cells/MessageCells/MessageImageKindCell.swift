//
//  MessageImageKindCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/12/18.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class MessageImageKindCell: MessageBaseCell {
    
    func layoutImageKindView(_ targetView: UIView) {
        if message.imageSize == .zero {
            targetView.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
            return
        }
        let maxSize = CGSize(width: 2*self.contentView.frame.width/3, height: CGFloat.greatestFiniteMagnitude)
        let nameHeight = message.messageSender == .ourself ? 0 : nameLabel.bounds.height
        let height = contentView.bounds.height - 30 - nameHeight - (message.referMessage == nil ? 0 : ReferView.height + ReferView.margin)
        let width = message.imageSize.width * height / message.imageSize.height
        var size = CGSize(width: width, height: height)
        var scale: CGFloat = 1
        if size.width > maxSize.width {
            scale = maxSize.width / size.width
        }
        size.width *= scale
        size.height *= scale
        targetView.bounds = CGRect(origin: .zero, size: size)
        targetView.layer.cornerRadius = min(size.width, size.height) / 12
    }
    
}
