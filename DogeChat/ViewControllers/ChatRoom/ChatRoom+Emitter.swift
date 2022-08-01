//
//  ChatRoomViewController+Emitter.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/6.
//  Copyright © 2021 赵锡光. All rights reserved.
//

extension ChatRoomViewController {
    
    func avatarDoubleTap(_ cell: MessageBaseCell) {
        if let myLatestCell = (tableView.visibleCells as! [MessageBaseCell]).filter({ $0.message.messageSender == .ourself }).sorted(by: { $0.indexPath.item > $1.indexPath.item }).first {
            let emitterLayer = EmojiEmitterLayer(strs: ["🍉🍇"], count: 50, fromView: myLatestCell.avatarContainer, toView: cell.avatarContainer)
            myLatestCell.contentView.layer.addSublayer(emitterLayer)
            myLatestCell.layer.zPosition = 10000
        }
    }
    
}
