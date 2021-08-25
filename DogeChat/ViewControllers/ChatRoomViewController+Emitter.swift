//
//  ChatRoomViewController+Emitter.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/6.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

extension ChatRoomViewController {
    
    func avatarDoubleTap(_ cell: MessageCollectionViewBaseCell) {
        if let myLatestCell = (tableView.visibleCells as! [MessageCollectionViewBaseCell]).filter({ $0.message.messageSender == .ourself }).sorted(by: { $0.indexPath.item > $1.indexPath.item }).first {
            let emitterLayer = EmojiEmitterLayer(strs: ["🤛🏻"], count: 50, fromView: myLatestCell.avatarImageView, toView: cell.avatarImageView)
            myLatestCell.contentView.layer.addSublayer(emitterLayer)
            myLatestCell.layer.zPosition = 10000
        }
    }
    
}
