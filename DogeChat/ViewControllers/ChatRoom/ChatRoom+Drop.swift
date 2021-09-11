//
//  ChatRoomViewController+Drop.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/4/12.
//  Copyright © 2021 Xiguang Zhao. All rights reserved.
//
import DogeChatNetwork
import DogeChatUniversal
import PencilKit

extension ChatRoomViewController: UITableViewDropDelegate {
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        if let item = coordinator.items.first,
              let passedObject = item.dragItem.localObject as? [Any?],
              let imageLink = passedObject[0] as? String,
           let cache = passedObject[1] as? NSCache<NSString, NSData> { // 这是拖拽表情包
            if let destinationIndexPath = coordinator.destinationIndexPath {
                coordinator.session.loadObjects(ofClass: UIImage.self) { (images) in
                    for _image in images {
                        let image = _image as! UIImage
                        if let cell = tableView.cellForRow(at: destinationIndexPath) as? MessageCollectionViewBaseCell {
                            cell.didDrop(imageLink: imageLink, image: image, point: coordinator.session.location(in: cell.contentView), cache: cache)
                        }
                    }
                }
            }
        } else if let local = coordinator.items.first?.dragItem.localObject as? String, local == "local" {
            
        } else { //这是从别的app拖过来的
            var textMessages = [Message]()
            var imageItems = [NSItemProvider]()
            let imageCount = coordinator.items.filter( { $0.dragItem.itemProvider.canLoadObject(ofClass: UIImage.self) }).count
            let strCount = coordinator.items.filter( { $0.dragItem.itemProvider.canLoadObject(ofClass: String.self) }).count
            for item in coordinator.items {
                if item.dragItem.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    imageItems.append(item.dragItem.itemProvider)
                    if imageItems.count == imageCount {
                        self.processItemProviders(imageItems)
                    }
                } else if item.dragItem.itemProvider.canLoadObject(ofClass: String.self) {
                    _ = item.dragItem.itemProvider.loadObject(ofClass: String.self) { [weak self] str, error in
                        guard let self = self, let str = str else {
                            return
                        }
                        let message = Message(message: str, messageSender: .ourself, sender: self.username, messageType: .text, option: self.messageOption)
                        message.receiver = self.friendName
                        message.sendStatus = .fail
                        textMessages.append(message)
                        if textMessages.count == strCount {
                            self.insertNewMessageCell(textMessages)
                            for newMessage in textMessages {
                                socketForUsername(self.username).sendWrappedMessage(newMessage)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: UIImage.self) || session.canLoadObjects(ofClass: String.self)
    }
        
    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        return .init(operation: .copy)
    }
}
