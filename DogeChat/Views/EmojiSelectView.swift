//
//  EmojiSelectView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/2/23.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

@objc protocol EmojiViewDelegate: class {
    @objc optional func didSelectEmoji(filePath: String)
    @objc optional func deleteEmoji(cell: EmojiCollectionViewCell)
}

class EmojiSelectView: UIView {

    weak var delegate: EmojiViewDelegate?
    let collectionView: UICollectionView!
    var emojis: [String] = WebSocketManager.shared.emojiPaths {
        didSet {
            self.isHidden = false
            if emojis != oldValue {
                collectionView.reloadData()
                WebSocketManager.shared.emojiPaths = emojis
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
        collectionView.translatesAutoresizingMaskIntoConstraints = false;
        if #available(iOS 13.0, *) {
            collectionView.backgroundColor = .systemBackground
        } else {
            collectionView.backgroundColor = .white
        }
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: self.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: self.bottomAnchor),

        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension EmojiSelectView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDelegate, UICollectionViewDataSourcePrefetching, EmojiViewDelegate {
    
    func deleteEmoji(cell: EmojiCollectionViewCell) {
        if let indexPath = cell.indexPath {
            WebSocketManager.shared.deleteEmoji(emojis[indexPath.item]) { [self] in
                collectionView.deleteItems(at: [indexPath])
                emojis.remove(at: indexPath.item)
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
                            let compressed = WebSocketManager.shared.compressEmojis(image)
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
        let width = UIScreen.main.bounds.width / 4 - 2
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
    
    @available(iOS 13.0, *)
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let cell = collectionView.cellForItem(at: indexPath) as? EmojiCollectionViewCell else { return nil }
        let identifier = "\(indexPath.row)" as NSString
        return .init(identifier: identifier, previewProvider: nil) { (menu) -> UIMenu? in
            return UIMenu(title: "", image: nil, children: [UIAction(title: "删除") { _ in
                self.deleteEmoji(cell: cell)
            }])
        }
    }
    
}

extension EmojiSelectView: UICollectionViewDragDelegate {
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        session.localContext = collectionView
        guard let cell = collectionView.cellForItem(at: indexPath) as? EmojiCollectionViewCell, let image = cell.emojiView.image else { return [] }
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

