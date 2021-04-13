//
//  ChatRoomViewController+Drop.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/4/12.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

extension ChatRoomViewController: UICollectionViewDropDelegate {
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let item = coordinator.items.first,
              let passedObject = item.dragItem.localObject as? [Any?],
              let imageLink = passedObject[0] as? String,
              let cache = passedObject[1] as? NSCache<NSString, NSData>
              else { return }
        if let destinationIndexPath = coordinator.destinationIndexPath {
            coordinator.session.loadObjects(ofClass: UIImage.self) { (images) in
                for _image in images {
                    let image = _image as! UIImage
                    if let cell = collectionView.cellForItem(at: destinationIndexPath) as? MessageCollectionViewCell {
                        cell.didDrop(imageLink: imageLink, image: image, point: coordinator.session.location(in: cell.contentView), cache: cache)
                    }
                }
            }
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: UIImage.self)
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        return .init(operation: .copy)
    }
}
