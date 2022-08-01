//
//  EmojiSelectView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/2/23.
//  Copyright © 2021 Xiguang Zhao. All rights reserved.
//

import UIKit
import DogeChatNetwork
import SwiftyJSON
import DogeChatUniversal
import Foundation
import DogeChatCommonDefines

protocol EmojiViewDelegate: AnyObject {
    func didSelectEmoji(emoji: Emoji)
    func emojiSelectViewCellMenus(_ cell: EmojiCollectionViewCell, parentCell: EmojiSelectView) -> [EmojiView.EmojiCellMenuItem]
    func didSelectMenuItem(_ cell: EmojiCollectionViewCell, parentCell: EmojiSelectView, item: EmojiView.EmojiCellMenuItem)
    func emojiSelectViewOnTapAddButton(_ cell: EmojiSelectView)
}

class EmojiSelectView: DogeChatBaseCollectionViewCell {

    weak var delegate: EmojiViewDelegate?
    weak var vc: DogeChatViewController?
    let collectionView: DogeChatBaseCollectionView!
    var emojis: [Emoji] = [] {
        didSet {
            DispatchQueue.main.async {
                self.button.isHidden = !self.emojis.isEmpty
                self.collectionView.reloadData()
            }
        }
    }
    var manager: WebSocketManager?
    
    weak var activeEmojiCell: EmojiCollectionViewCell?
    
    let button = UIButton()
    
    static let cellID = "EmojiSelectView"
    
    override init(frame: CGRect) {
        collectionView = DogeChatBaseCollectionView(frame: frame, collectionViewLayout: UICollectionViewFlowLayout())
        super.init(frame: frame)
        self.contentView.addSubview(collectionView)
        collectionView.register(EmojiCollectionViewCell.self, forCellWithReuseIdentifier: EmojiCollectionViewCell.cellID)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dragInteractionEnabled = true
        collectionView.backgroundColor = .clear
        
        self.contentView.addSubview(button)
        button.setTitle(localizedString("clickToUpload"), for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        button.addTarget(self, action: #selector(onButtonTap), for: .touchUpInside)

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        button.translatesAutoresizingMaskIntoConstraints = false
        let guide = self.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: guide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            button.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor)
        ])
    }
    
    deinit {
        SDWebImageManager.shared.imageCache.clear(with: .memory, completion: nil)
    }
            
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func onButtonTap() {
        self.delegate?.emojiSelectViewOnTapAddButton(self)
    }
            
}

extension EmojiSelectView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDelegate, UICollectionViewDataSourcePrefetching, EmojiSelectCellLongPressDelegate {
    
    func didLongPressEmojiCell(_ cell: EmojiCollectionViewCell) {
        guard let menuItems = self.delegate?.emojiSelectViewCellMenus(cell, parentCell: self), !menuItems.isEmpty else { return }
        self.activeEmojiCell = cell
        var items = [UIMenuItem]()
        let controller = UIMenuController.shared
        for menuItem in menuItems {
            let selector: Selector
            switch menuItem {
            case .delete:
                selector = #selector(dogechat_deleteMenuItemAction(sender:))
            case .useAsGroupAvatar:
                selector = #selector(dogechat_useAsGroupAvatar(sender:))
            case .useAsSelfAvatar:
                selector = #selector(dogechat_useAsAvatar(sender:))
            case .addEmojis:
                selector = #selector(dogechat_addEmojiMenuItemAction(sender:))
            case .preview:
                selector = #selector(dogechat_previewEmojiMenuItemAction(sender:))
            case .addToCommon:
                selector = #selector(dogechat_addToCommon(sender:))
            case .favorite:
                selector = #selector(dogechat_favorite(sender:))
            }
            items.append(UIMenuItem(title: menuItem.localizedString(), action: selector))
        }
        controller.menuItems = items
        self.becomeFirstResponder()
        let rect = cell.convert(cell.bounds, to: self)
        if #available(iOS 13.0, *) {
            controller.showMenu(from: self, rect: rect)
        } else {
            controller.setTargetRect(rect, in: self)
            controller.setMenuVisible(true, animated: true)
        }
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if NSStringFromSelector(action).hasPrefix("dogechat") {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }
            
    func updateDownloadProgress(_ cell: EmojiCollectionViewCell, progress: Double, path: String) {
        
    }
    
    @objc func dogechat_favorite(sender: UIMenuController) {
        guard let cell = self.activeEmojiCell else { return }
        self.delegate?.didSelectMenuItem(cell, parentCell: self, item: .favorite)
    }
    
    @objc func dogechat_addToCommon(sender: UIMenuController) {
        guard let cell = self.activeEmojiCell else { return }
        self.delegate?.didSelectMenuItem(cell, parentCell: self, item: .addToCommon)
    }
        
    @objc func dogechat_useAsAvatar(sender: UIMenuController) {
        guard let cell = self.activeEmojiCell else { return }
        self.delegate?.didSelectMenuItem(cell, parentCell: self, item: .useAsSelfAvatar)
    }

    @objc func dogechat_useAsGroupAvatar(sender: UIMenuController) {
        guard let cell = self.activeEmojiCell else { return }
        self.delegate?.didSelectMenuItem(cell, parentCell: self, item: .useAsGroupAvatar)
    }

    @objc func dogechat_deleteMenuItemAction(sender: UIMenuController) {
        guard let cell = self.activeEmojiCell else { return }
        self.delegate?.didSelectMenuItem(cell, parentCell: self, item: .delete)
    }
    
    @objc func dogechat_addEmojiMenuItemAction(sender: UIMenuController) {
        guard let cell = self.activeEmojiCell else { return }
        self.delegate?.didSelectMenuItem(cell, parentCell: self, item: .addEmojis)
    }
    
    @objc func dogechat_previewEmojiMenuItemAction(sender: UIMenuController) {
        guard let cell = self.activeEmojiCell else { return }
        self.delegate?.didSelectMenuItem(cell, parentCell: self, item: .preview)
    }
    
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
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
        playHaptic()
        delegate?.didSelectEmoji(emoji: emojis[indexPath.item])
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiCollectionViewCell.cellID, for: indexPath) as? EmojiCollectionViewCell else {
            return UICollectionViewCell()
        }
        cell.indexPath = indexPath
        cell.delegate = self
        if indexPath.item < self.emojis.count {
            cell.displayEmoji(emoji: self.emojis[indexPath.item])
        }
        return cell
    }
    
    @available(iOS 13.0, *)
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        if !isMac() { return nil }
        let identifier = "\(indexPath.row)" as NSString
        return UIContextMenuConfiguration(identifier: identifier, previewProvider: { [weak self] in
            guard let self = self else { return nil }
            let vc = MediaBrowserViewController()
            vc.imagePaths = [self.emojis[indexPath.item].path]
            return vc
        }) { [weak self] elements -> UIMenu? in
            return self?.makeMenus(for: indexPath)
        }
    }
    
    @available(iOS 13.0, *)
    func makeMenus(for indexPath: IndexPath) -> UIMenu? {
        guard let cell = collectionView.cellForItem(at: indexPath) as? EmojiCollectionViewCell, let items = self.delegate?.emojiSelectViewCellMenus(cell, parentCell: self), !items.isEmpty else { return nil }
        var res = [UIAction]()
        for item in items {
            let action = UIAction(title: item.localizedString()) { [weak self, weak cell] _ in
                if let self = self, let cell = cell {
                    self.delegate?.didSelectMenuItem(cell, parentCell: self, item: item)
                }
            }
            res.append(action)
        }
        return UIMenu(title: "", image: nil, children: res)
    }
    
    
}
