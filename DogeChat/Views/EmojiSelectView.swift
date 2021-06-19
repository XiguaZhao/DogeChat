//
//  EmojiSelectView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/2/23.
//  Copyright © 2021 Xiguang Zhao. All rights reserved.
//

import UIKit
import YPTransition
import SwiftyJSON

@objc protocol EmojiViewDelegate: AnyObject {
    @objc optional func didSelectEmoji(filePath: String)
    @objc optional func deleteEmoji(cell: EmojiCollectionViewCell)
}

class EmojiSelectView: UIView {

    weak var delegate: EmojiViewDelegate?
    let collectionView: UICollectionView!
    var emojis: [String] = WebSocketManager.shared.messageManager.emojiPaths {
        didSet {
            self.isHidden = false
            if emojis != oldValue {
                collectionView.reloadData()
                WebSocketManager.shared.messageManager.emojiPaths = emojis
            }
        }
    }
    static var emojiPathToId: [String: String] = [:]
    let cache = NSCache<NSString, NSData>()
    
    override init(frame: CGRect) {
        collectionView = UICollectionView(frame: frame, collectionViewLayout: UICollectionViewFlowLayout())
        super.init(frame: frame)
        addSubview(collectionView)
        collectionView.register(EmojiCollectionViewCell.self, forCellWithReuseIdentifier: EmojiCollectionViewCell.cellID)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.prefetchDataSource = self
        collectionView.dragDelegate = self
        collectionView.dragInteractionEnabled = true
        configure()
    }
    
    deinit {
        SDWebImageManager.shared.imageCache.clear(with: .memory, completion: nil)
    }
    
    private func configure() {
        if #available(iOS 13.0, *) {
            collectionView.backgroundColor = .systemBackground
        } else {
            collectionView.backgroundColor = .white
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.frame = self.bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension EmojiSelectView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDelegate, UICollectionViewDataSourcePrefetching, EmojiSelectCellLongPressDelegate {
    
    func didLongPressEmojiCell(_ cell: EmojiCollectionViewCell) {
        let alert = UIAlertController(title: "选中当前Emoji", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "设为自己头像", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            self.useAsSelfAvatar(cell: cell)
        }))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive, handler: { [weak self] _ in
            guard let self = self else { return }
            let confirmAlert = UIAlertController(title: "确认删除？", message: nil, preferredStyle: .alert)
            confirmAlert.addAction(UIAlertAction(title: "确认", style: .default, handler: { _ in
                self.deleteEmoji(cell: cell)
            }))
            confirmAlert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
            AppDelegate.shared.navigationController.present(confirmAlert, animated: true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        AppDelegate.shared.navigationController.present(alert, animated: true, completion: nil)
    }
    
    func deleteEmoji(cell: EmojiCollectionViewCell) {
        if let indexPath = cell.indexPath, let id = EmojiSelectView.emojiPathToId[emojis[indexPath.item]] {
            WebSocketManager.shared.deleteEmoji(emojis[indexPath.item], id: id) { [self] in
                collectionView.deleteItems(at: [indexPath])
                emojis.remove(at: indexPath.item)
            }
        }
    }
    
    func useAsSelfAvatar(cell: EmojiCollectionViewCell) {
        if let index = cell.indexPath?.item {
            let path = (emojis[index] as NSString).replacingOccurrences(of: WebSocketManager.shared.url_pre, with: "")
            WebSocketManager.shared.changeAvatarWithPath(path) { task, data in
                guard let data = data else { return }
                if JSON(data)["status"].stringValue == "success" {
                    WebSocketManager.shared.messageManager.myAvatarUrl = WebSocketManager.shared.url_pre + JSON(data)["avatarUrl"].stringValue
                }
            }
        }
    }
        
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            if indexPath.item >= emojis.count { continue }
            let imageLink = emojis[indexPath.item]
            if cache.object(forKey: imageLink as NSString) == nil {
                SDWebImageManager.shared.loadImage(with: URL(string: imageLink), options: .avoidDecodeImage, context: [SDWebImageContextOption.imageCache: SDImageCacheType.memory], progress: nil) { [self] (image, data, error, cacheType, finished, url) in
                    guard error == nil else { return }
                    DispatchQueue.global().async {
                        if let data = data,
                              let image = UIImage(data: data) {
                            let compressed = WebSocketManager.shared.messageManager.compressEmojis(image)
                            cache.setObject(compressed as NSData, forKey: (imageLink as NSString))
                        } else if let image = image,
                                  let compressed = image.pngData() {
                            cache.setObject(compressed as NSData, forKey: imageLink as NSString)
                        }
                    }
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return emojis.count
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = 90
        return CGSize(width: width, height: width)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.didSelectEmoji?(filePath: emojis[indexPath.item])
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiCollectionViewCell.cellID, for: indexPath) as? EmojiCollectionViewCell else {
            return UICollectionViewCell()
        }
        cell.indexPath = indexPath
        cell.path = emojis[indexPath.item]
        cell.delegate = self
        cell.cache = cache
        cell.displayEmoji(urlString: emojis[indexPath.item])
        return cell
    }
    
//    @available(iOS 13.0, *)
//    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
//        guard let cell = collectionView.cellForItem(at: indexPath) as? EmojiCollectionViewCell else { return nil }
//        let identifier = "\(indexPath.row)" as NSString
//        return .init(identifier: identifier, previewProvider: nil) { (menu) -> UIMenu? in
//            let deleteAction = UIAction(title: "删除") { [weak self, weak cell] _ in
//                if let cell = cell {
//                    self?.deleteEmoji(cell: cell)
//                }
//            }
//            let avatarAction = UIAction(title: "设为自己头像") { [weak self, weak cell] _ in
//                if let cell = cell {
//                    self?.useAsSelfAvatar(cell: cell)
//                }
//            }
//            return UIMenu(title: "", image: nil, children: [deleteAction, avatarAction])
//        }
//    }
    
}

extension EmojiSelectView: UICollectionViewDragDelegate {
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        session.localContext = collectionView
        weak var weakCell = collectionView.cellForItem(at: indexPath) as? EmojiCollectionViewCell
        guard let cell = weakCell, let image = cell.emojiView.image else { return [] }
        let dragItem = UIDragItem(itemProvider: NSItemProvider(object: image))
        dragItem.localObject = [cell.url?.absoluteString ?? "", cache]
        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        let preview = UIDragPreviewParameters()
        guard let cell = collectionView.cellForItem(at: indexPath) as? EmojiCollectionViewCell, let image = cell.emojiView.image else { return nil }
        let viewSize = cell.contentView.bounds.size
        var rect = AVMakeRect(aspectRatio: image.size, insideRect: cell.emojiView.bounds)
        rect = CGRect(x:((viewSize.width - rect.width) / 2), y: ((viewSize.height - rect.height) / 2), width: rect.width, height: rect.height)
        let path = UIBezierPath(rect: rect)
        preview.visiblePath = path
        return preview
    }
    
}

