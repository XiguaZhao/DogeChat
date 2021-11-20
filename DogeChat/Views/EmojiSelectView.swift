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

@objc protocol EmojiViewDelegate: AnyObject {
    @objc optional func didSelectEmoji(filePath: String)
    @objc optional func deleteEmoji(cell: EmojiCollectionViewCell)
}

class EmojiSelectView: DogeChatStaticBlurView {

    weak var delegate: EmojiViewDelegate?
    let collectionView: DogeChatBaseCollectionView!
    var emojis: [String] {
        get {
            HttpRequestsManager.emojiPaths
        }
        set {
            self.isHidden = false
            HttpRequestsManager.emojiPaths = newValue
            collectionView.reloadData()
        }
    }
    static var emojiPathToId: [String: String] = [:]
    var username = ""
    var friend: Friend!
    var manager: WebSocketManager {
        socketForUsername(username)
    }
    
    override init(frame: CGRect) {
        collectionView = DogeChatBaseCollectionView(frame: frame, collectionViewLayout: UICollectionViewFlowLayout())
        super.init(frame: frame)
        addSubview(collectionView)
        NotificationCenter.default.addObserver(self, selector: #selector(emojiHasChangeNoti(_:)), name: .emojiHasChange, object: nil)
        collectionView.register(EmojiCollectionViewCell.self, forCellWithReuseIdentifier: EmojiCollectionViewCell.cellID)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.dragDelegate = self
        collectionView.dragInteractionEnabled = true
        collectionView.backgroundColor = .clear
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        let guide = self.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: guide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }
    
    deinit {
        SDWebImageManager.shared.imageCache.clear(with: .memory, completion: nil)
    }
            
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func emojiHasChangeNoti(_ noti: Notification) {
        self.collectionView.reloadData()
    }
    
}

extension EmojiSelectView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDelegate, UICollectionViewDataSourcePrefetching, EmojiSelectCellLongPressDelegate {
    
    func didLongPressEmojiCell(_ cell: EmojiCollectionViewCell) {
        let avatarMenuItem = UIMenuItem(title: "设为自己头像", action: #selector(useAsAvatar(sender:)))
        let deleteMenuItem = UIMenuItem(title: "删除", action: #selector(deleteMenuItemAction(sender:)))
        let controller = UIMenuController.shared
        var items = [avatarMenuItem, deleteMenuItem]
        if friend.isGroup {
            items.append(UIMenuItem(title: "设为群聊头像", action: #selector(useAsGroupAvatar(sender:))))
        }
        controller.menuItems = items
        cell.becomeFirstResponder()
        let rect = CGRect(x: cell.bounds.width/2, y: 10, width: 0, height: 0)
        if #available(iOS 13.0, *) {
            controller.showMenu(from: cell, rect: rect)
        } else {
            controller.setTargetRect(rect, in: cell)
            controller.setMenuVisible(true, animated: true)
        }
    }
    
    func updateDownloadProgress(_ cell: EmojiCollectionViewCell, progress: Double, path: String) {
        
    }
    
    @objc func useAsAvatar(sender: UIMenuController) {
        guard let cell = sender.value(forKey: "targetView") as? EmojiCollectionViewCell else { return }
        useAsSelfAvatar(cell: cell)
    }
    
    @objc func useAsGroupAvatar(sender: UIMenuController) {
        guard let cell = sender.value(forKey: "targetView") as? EmojiCollectionViewCell else { return }
        useAsSelfAvatar(cell: cell, append: "&groupId=\(self.friend.userID)")
    }
    
    @objc func deleteMenuItemAction(sender: UIMenuController) {
        guard let cell = sender.value(forKey: "targetView") as? EmojiCollectionViewCell else { return }
        let confirmAlert = UIAlertController(title: "确认删除？", message: nil, preferredStyle: .alert)
        confirmAlert.addAction(UIAlertAction(title: "确认", style: .default, handler: { _ in
            self.deleteEmoji(cell: cell)
        }))
        confirmAlert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        AppDelegate.shared.navigationController?.present(confirmAlert, animated: true, completion: nil)
    }

    func deleteEmoji(cell: EmojiCollectionViewCell) {
        if let indexPath = cell.indexPath, let id = EmojiSelectView.emojiPathToId[emojis[indexPath.item]] {
            manager.deleteEmoji(emojis[indexPath.item], id: id) { [self] in
                manager.getEmojis { _ in
                    
                }
            }
        }
    }
    
    func useAsSelfAvatar(cell: EmojiCollectionViewCell, append: String? = nil) {
        if let index = cell.indexPath?.item {
            var path = (emojis[index] as NSString).replacingOccurrences(of: url_pre, with: "")
            if let append = append {
                path += append
            }
            manager.changeAvatarWithPath(path) { [self] task, data in
                guard let data = data else { return }
                let json = JSON(data)
                if json["status"].stringValue == "success" {
                    let avatarURL = json["avatarUrl"].stringValue
                    if append != nil {
                        if let friend = socketForUsername(username).httpsManager.friends.first(where: { $0.userID == self.friend.userID } ) {
                            friend.avatarURL = avatarURL
                            NotificationCenter.default.post(name: .friendChangeAvatar, object: username, userInfo: ["friend": friend])
                        }
                    } else {
                        self.manager.messageManager.myAvatarUrl = url_pre + JSON(data)["avatarUrl"].stringValue
                    }
                }
            }
        }
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
        delegate?.didSelectEmoji?(filePath: emojis[indexPath.item])
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiCollectionViewCell.cellID, for: indexPath) as? EmojiCollectionViewCell else {
            return UICollectionViewCell()
        }
        cell.indexPath = indexPath
        cell.path = emojis[indexPath.item]
        cell.delegate = self
        cell.displayEmoji(urlString: emojis[indexPath.item])
        return cell
    }
    
#if targetEnvironment(macCatalyst)
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return nil
    }
#endif
    
}

extension EmojiSelectView: UICollectionViewDragDelegate {
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        session.localContext = collectionView
        weak var weakCell = collectionView.cellForItem(at: indexPath) as? EmojiCollectionViewCell
        guard let cell = weakCell, let image = cell.emojiView.image else { return [] }
        let dragItem = UIDragItem(itemProvider: NSItemProvider(object: image))
        dragItem.localObject = [cell.url?.absoluteString ?? ""]
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

