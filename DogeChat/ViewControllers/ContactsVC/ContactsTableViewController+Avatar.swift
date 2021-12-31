//
//  ContactsTableViewController+Avatar.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/5.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import Foundation
import SwiftyJSON
import DogeChatNetwork
import DogeChatUniversal

extension ContactsTableViewController: ContactTableViewCellDelegate, UIContextMenuInteractionDelegate {
    func avatarTapped(_ cell: ContactTableViewCell?, path: String) {
        let browser = MediaBrowserViewController()
        browser.modalPresentationStyle = .fullScreen
        browser.imagePaths = [path]
        self.navigationController?.present(browser, animated: true, completion: nil)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        DispatchQueue.main.async {
            self.setupMyAvatar()
        }
    }
    
    func setupMyAvatar() {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 17)
        label.text = self.username
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.layer.masksToBounds = true
        avatarImageView.layer.cornerRadius = 22;
        let stackView = UIStackView(arrangedSubviews: [avatarImageView, label])
        stackView.spacing = 10
        avatarImageView.mas_updateConstraints { [weak self] make in
            make?.width.mas_equalTo()(self?.avatarImageView.mas_height)
        }
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressRightButton(sender:)))
        longPress.minimumPressDuration = 0.2
        stackView.addGestureRecognizer(longPress)
        self.navigationItem.titleView = stackView
        DispatchQueue.main.async { [self] in
            if let bar = navigationController?.navigationBar {
                avatarImageView.layer.cornerRadius = bar.bounds.height / 2
            }
        }

        stackView.isUserInteractionEnabled = true
        let tapAvatar = UITapGestureRecognizer(target: self, action: #selector(titleViewTap(_:)))
        stackView.addGestureRecognizer(tapAvatar)
        if let url = manager?.httpsManager.accountInfo.avatarURL, !url.isEmpty {
            updateMyAvatar(url: url)
        }
    }
    
    @objc func longPressRightButton(sender: UILongPressGestureRecognizer!) {
        if sender.state == .began {
            playHaptic()
        }
        guard let manager = manager, sender.state == .ended else {
            return
        }
        let browser = MediaBrowserViewController()
        browser.imagePaths = [manager.messageManager.myAvatarUrl]
        self.splitViewController?.present(browser, animated: true, completion: nil)
        playHaptic()
    }
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        return .init(identifier: nil) { [weak self] in
            guard let self = self, let manager = self.manager else { return nil }
            let browser = MediaBrowserViewController()
            browser.imagePaths = [manager.messageManager.myAvatarUrl]
            return browser
        } actionProvider: { _ in
            return nil
        }
    }
        
    @objc func updateMyAvatar(_ noti: Notification) {
        guard noti.object as? String == self.username,
              let url = noti.userInfo?["path"] as? String
        else { return }
        updateMyAvatar(url: url)
    }
    
    func updateMyAvatar(url: String) {
        if self.lastAvatarURL == url && (avatarImageView.image != nil || avatarImageView.animatedImage != nil) { return }
        lastAvatarURL = url
        MediaLoader.shared.requestImage(urlStr: url, type: .image, cookie: manager?.cookie) { [self] image, data, _ in
            guard let data = data else { return }
            if url.hasSuffix(".gif") {
                avatarImageView.animatedImage = FLAnimatedImage(gifData: data)
            } else {
                avatarImageView.image = UIImage(data: data)
            }
            for chatVC in findChatRoomVCs() {
                chatVC.tableView.reloadData()
            }
        }
    }
    
    @objc func friendChangeAvatar(_ noti: Notification) {
        guard noti.object as? String == self.username else { return }
        let friend = noti.userInfo?["friend"] as! Friend
        if let index = self.friends.firstIndex(of: friend) {
            self.friends[index].avatarURL = friend.avatarURL
            tableView.reloadData()
            for chatVC in findChatRoomVCs() {
                for message in chatVC.messages where message.senderUserID == friend.userID {
                    message.avatarUrl = friend.avatarURL
                }
                chatVC.tableView.reloadData()
            }
        }
    }
    
    @objc func titleViewTap(_ tap: UITapGestureRecognizer) {
        self.navigationController?.setViewControllersForSplitVC(vcs: [self, ProfileVC()])
    }
        

}
