//
//  EmojiSelectView+Drop.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/15.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import Foundation
import UIKit

extension EmojiSelectView: UICollectionViewDropDelegate {
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        
    }
    
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        return false
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        return .init(operation: .copy)
    }
    
}
