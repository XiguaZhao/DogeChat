//
//  ChatRoom+Drag.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/9/5.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

extension ChatRoomViewController: UITableViewDragDelegate {
    
    
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let message = messages[indexPath.row]
        guard message.messageType == .image || message.messageType == .text else { return [] }
        var items = [UIDragItem]()
        if message.messageType == .text {
            let str = message.message as NSString
            let item = UIDragItem(itemProvider: NSItemProvider(object: str))
            items.append(item)
        } else if message.messageType == .image {
            var imagePath = message.imageURL ?? ""
            imagePath.removeFirst()
            let str = url_pre + imagePath
            if let key = SDWebImageManager.shared.cacheKey(for: URL(string: str)),
               let image = SDImageCache.shared.imageFromCache(forKey: key) {
                let item = UIDragItem(itemProvider: NSItemProvider(object: image))
                items.append(item)
            }
        }
        items.forEach( { $0.localObject = "local" })
        return items
    }
    
    func tableView(_ tableView: UITableView, dragPreviewParametersForRowAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        let preview = UIDragPreviewParameters()
        let message = messages[indexPath.row]
        guard let cell = tableView.cellForRow(at: indexPath) as? MessageCollectionViewBaseCell else { return nil }
        var rect: CGRect?
        if message.messageType == .text {
            rect = (cell as! MessageCollectionViewTextCell).messageLabel.frame
        } else if message.messageType == .image {
            rect = (cell as! MessageCollectionViewImageCell).animatedImageView.frame
        }
        guard var rect = rect, let targetView = cell.indicationNeighborView else {
            return nil
        }
        let offset = cell.bounds.width - cell.contentView.bounds.width
        rect.origin.x += offset
        let path = UIBezierPath(roundedRect: rect, cornerRadius: targetView.layer.cornerRadius)
        preview.visiblePath = path
        return preview

    }
    
}
