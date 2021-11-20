//
//  ChatRoom+Drag.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/9/5.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit

extension ChatRoomViewController: UITableViewDragDelegate {
    
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let message = messages[indexPath.row]
        guard message.messageType == .image || message.messageType == .text || message.messageType == .draw || message.messageType == .voice || message.messageType == .video else { return [] }
        var items = [UIDragItem]()
        if message.messageType == .text {
            let str = message.text as NSString
            let item = UIDragItem(itemProvider: NSItemProvider(object: str))
            items.append(item)
        } else if message.messageType == .image || message.messageType == .voice || message.messageType == .video {
            let type = message.messageType
            let dirName = type == .image ? photoDir : (type == .video ? videoDir : voiceDir)
            let urlStr = type == .image ? message.imageURL : (type == .video ? message.videoURL : message.voiceURL)
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
            if #available(iOS 13, *) {
                if let url = fileURLAt(dirName: drawDir, fileName: (message.pkDataURL ?? "").components(separatedBy: "/").last ?? ""), let data = try? Data(contentsOf: url), let draw = try? PKDrawing(data: data) {
                    #if !targetEnvironment(macCatalyst)
                    let image = draw.image(from: draw.bounds, scale: UIScreen.main.scale)
                    let item = UIDragItem(itemProvider: NSItemProvider(object: image))
                    items.append(item)
                    #endif
                }
            }
        }
        items.forEach( { $0.localObject = "local" })
        return items
    }
    
    func tableView(_ tableView: UITableView, dragPreviewParametersForRowAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        let preview = UIDragPreviewParameters()
        guard let cell = tableView.cellForRow(at: indexPath) as? MessageCollectionViewBaseCell else { return nil }
        let rect: CGRect? = cell.indicationNeighborView?.frame
        guard var rect = rect, let targetView = cell.indicationNeighborView else {
            return nil
        }
        let offset = cell.bounds.width - cell.contentView.bounds.width
        rect.origin.x += offset
        let path = UIBezierPath(roundedRect: rect, cornerRadius: targetView.layer.cornerRadius)
        let avatarPath = UIBezierPath(roundedRect: cell.avatarImageView.frame, cornerRadius: cell.avatarImageView.layer.cornerRadius)
        path.append(avatarPath)
        preview.visiblePath = path
        return preview

    }
    
}
