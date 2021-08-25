//
//  ChatRoomViewController+Drop.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/4/12.
//  Copyright © 2021 Xiguang Zhao. All rights reserved.
//
import DogeChatNetwork

extension ChatRoomViewController: UITableViewDropDelegate {
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        guard let item = coordinator.items.first,
              let passedObject = item.dragItem.localObject as? [Any?],
              let imageLink = passedObject[0] as? String,
              let cache = passedObject[1] as? NSCache<NSString, NSData>
              else { return }
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
    }
    
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: UIImage.self)
    }
        
    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        return .init(operation: .copy)
    }
}
