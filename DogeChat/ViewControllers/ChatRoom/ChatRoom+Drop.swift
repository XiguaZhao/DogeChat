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
import Foundation
import AVFoundation

extension ChatRoomViewController: UITableViewDropDelegate {
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        for item in coordinator.items {
            if let passedObject = item.dragItem.localObject as? [String : Any?],
                  let imageLink = passedObject["emojiURL"] as? String { // 这是拖拽表情包
                if let destinationIndexPath = coordinator.destinationIndexPath {
                    coordinator.session.loadObjects(ofClass: UIImage.self) { (images) in
                        for _image in images {
                            let image = _image as! UIImage
                            if let cell = tableView.cellForRow(at: destinationIndexPath) as? MessageBaseCell {
                                cell.didDrop(imageLink: imageLink, image: image, point: coordinator.session.location(in: cell.contentView))
                            }
                        }
                    }
                }
            } else if let info = item.dragItem.localObject as? [String : Any], let userID = info["userID"] as? String {
                if userID != friend.userID, let message = info["message"] as? Message {
                    Self.transferMessages([message], to: [self.friend], manager: self.manager)
                }
            } else { //这是从别的app拖过来的
                var textMessages = [Message]()
                let itemProvider = item.dragItem.itemProvider
                if itemProvider.canLoadObject(ofClass: UIImage.self) {
                    self.processItemProviders([item.dragItem.itemProvider])
                } else if itemProvider.hasItemConformingToTypeIdentifier(videoIdentifier) || itemProvider.hasItemConformingToTypeIdentifier(audioIdentifier) {
                    self.processItemProviders([itemProvider])
                } else if itemProvider.canLoadObject(ofClass: String.self) {
                    _ = item.dragItem.itemProvider.loadObject(ofClass: String.self) { [weak self] str, error in
                        guard let self = self, let str = str else {
                            return
                        }
                        if let message = self.processMessageString(for: str, type: .text, imageURL: nil, videoURL: nil) {
                            textMessages.append(message)
                        }
                        self.insertNewMessageCell(textMessages)
                        for newMessage in textMessages {
                            socketForUsername(self.username)?.commonWebSocket.sendWrappedMessage(newMessage)
                        }
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        var res = session.canLoadObjects(ofClass: UIImage.self) || session.canLoadObjects(ofClass: String.self)
        res = res || session.hasItemsConforming(toTypeIdentifiers: [videoIdentifier])
        res = res || session.hasItemsConforming(toTypeIdentifiers: [audioIdentifier])
        return res
    }
        
    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        return .init(operation: .copy)
    }
}
