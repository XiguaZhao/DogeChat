//
//  ChatRoomCollectionViewLayout.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/4/15.
//  Copyright © 2021 Xiguang Zhao. All rights reserved.
//

import DogeChatNetwork

class ChatRootCollectionViewLayout: UICollectionViewFlowLayout {
    
    
//    var indexPathsToReload: [IndexPath] = []
//    
//    override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
//        if indexPathsToReload.contains(itemIndexPath), let index =  indexPathsToReload.firstIndex(of: itemIndexPath) {
//            indexPathsToReload.remove(at: index)
//            return nil
//        }
//        if itemIndexPath.item >= ChatRoomViewController.numberOfHistory - 1 || collectionView?.numberOfItems(inSection: 0) ?? 0 < ChatRoomViewController.numberOfHistory {
//            return nil
//        }
//        let originalAttr = layoutAttributesForItem(at: itemIndexPath)
//        let newAttr = UICollectionViewLayoutAttributes(forCellWith: itemIndexPath)
//        let index = CGFloat(itemIndexPath.item)
//        if let original = originalAttr {
//            newAttr.frame = original.frame
//            newAttr.alpha = max((10 - index) * 0.1, 0)
//            newAttr.center = .init(x: original.center.x, y: original.center.y + min(index * 100, UIScreen.main.bounds.height))
//        }
//        return newAttr
//    }
//    
//    override func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
//        var toReload = [IndexPath]()
//        for item in updateItems {
//            if item.updateAction == .reload {
//                toReload.append(item.indexPathAfterUpdate!)
//            }
//        }
//        indexPathsToReload = toReload
//    }
//    
    
    
}
