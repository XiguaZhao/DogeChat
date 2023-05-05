//
//  ChatRoom+Drag.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/9/5.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatUniversal
import PencilKit
import DogeChatCommonDefines

extension ChatRoomViewController: UITableViewDragDelegate {
    
    func tableView(_ tableView: UITableView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        return wrapItemsWithIndexPath(indexPath)
    }
    
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        self.messageInputBar.textViewResign()
        return wrapItemsWithIndexPath(indexPath)
    }
        
    func wrapItemsWithIndexPath(_ indexPath: IndexPath) -> [UIDragItem] {
        playHaptic()
        let message = messages[indexPath.section]
        guard message.messageType.isImage || message.messageType == .text || message.messageType == .draw || message.messageType == .voice || message.messageType == .video else { return [] }
        var items = [UIDragItem]()
        if message.messageType == .text {
            let str = message.text as NSString
            let item = UIDragItem(itemProvider: NSItemProvider(object: str))
            items.append(item)
        } else if message.messageType.isImage || message.messageType == .voice || message.messageType == .video {
            let type = message.messageType
            let dirName = type.isImage ? photoDir : (type == .video ? videoDir : voiceDir)
            let urlStr = type.isImage ? message.imageURL : (type == .video ? message.videoURL : message.voiceURL)
            var imagePath = urlStr ?? "/"
            if imagePath.isEmpty {
                imagePath = "/"
            }
            imagePath.removeFirst()
            let str = url_pre + imagePath
            if let fileName = URL(string: str)?.lastPathComponent, let localURL = fileURLAt(dirName: dirName, fileName: fileName) {
                let item = UIDragItem(itemProvider: NSItemProvider(contentsOf: localURL)!)
                items.append(item)
            }
        } else if message.messageType == .draw {
            if #available(iOS 13.0, *) {
                if let url = fileURLAt(dirName: drawDir, fileName: (message.pkDataURL ?? "").components(separatedBy: "/").last ?? ""), let data = try? Data(contentsOf: url), let draw = try? PKDrawing(data: data) {
#if !targetEnvironment(macCatalyst)
                    let sticker = draw.image(from: draw.bounds, scale: UIScreen.main.scale)
                    let item = UIDragItem(itemProvider: NSItemProvider(object: sticker))
                    items.append(item)
#endif
                }
            } 
        }
        items.forEach( { $0.localObject = ["userID" : self.friend.userID, "message" : message] })
        return items
    }
    
    func tableView(_ tableView: UITableView, dragPreviewParametersForRowAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        let preview = UIDragPreviewParameters()
        guard let cell = tableView.cellForRow(at: indexPath) as? MessageBaseCell else { return nil }
        let rect: CGRect? = cell.indicationNeighborView?.frame
        guard var rect = rect, let targetView = cell.indicationNeighborView else {
            return nil
        }
        let offset = cell.bounds.width - cell.contentView.bounds.width - tableView.safeAreaInsets.left
        rect.origin.x += offset
        let path = UIBezierPath(roundedRect: rect, cornerRadius: targetView.layer.cornerRadius)
        if !cell.avatarImageView.isHidden {
            var avatarRect = cell.avatarContainer.frame
            avatarRect.origin.x += tableView.safeAreaInsets.left
            let avatarPath = UIBezierPath(roundedRect: avatarRect, cornerRadius: cell.avatarContainer.layer.cornerRadius)
            path.append(avatarPath)
        }
        preview.visiblePath = path
        return preview

    }
    
}
