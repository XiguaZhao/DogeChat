//
//  EmojiSelectView+Drag.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/14.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import Foundation
import UIKit
import DogeChatCommonDefines

extension EmojiSelectView: UICollectionViewDragDelegate {
    
    func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        return wrapDragItemFor(indexPath: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        return wrapDragItemFor(indexPath: indexPath)
    }
    
    func wrapDragItemFor(indexPath: IndexPath) -> [UIDragItem] {
        let path = emojis[indexPath.item].path
        let dragItem = UIDragItem(itemProvider: NSItemProvider(contentsOf: fileURLAt(dirName: photoDir, fileName: path.fileName)) ?? NSItemProvider())
        dragItem.localObject = ["emojiURL": path]
        playHaptic()
        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        let preview = UIDragPreviewParameters()
        guard let cell = collectionView.cellForItem(at: indexPath) as? EmojiCollectionViewCell else { return nil }
        let viewSize = cell.contentView.bounds.size
        var rect = AVMakeRect(aspectRatio: cell.bounds.size, insideRect: cell.emojiView.bounds)
        rect = CGRect(x:((viewSize.width - rect.width) / 2), y: ((viewSize.height - rect.height) / 2), width: rect.width, height: rect.height)
        let path = UIBezierPath(rect: rect)
        preview.visiblePath = path
        return preview
    }
    
}

