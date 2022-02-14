//
//  MessageImageKindCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/12/18.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class MessageImageKindCell: MessageBaseCell {
    
    var container = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(container)
        container.layer.masksToBounds = true
        indicationNeighborView = container
    }
    
    func addMainView(_ view: UIView) {
        container.addSubview(view)
        view.mas_makeConstraints { make in
            make?.edges.equalTo()(self.container)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func layoutImageKindView() {
        guard let targetView = indicationNeighborView else { return }
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
