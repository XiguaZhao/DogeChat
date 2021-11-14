//
//  ChatRoom+Avatar.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/10/29.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import FLAnimatedImage
import DogeChatUniversal

extension ChatRoomViewController {
    
    func makeTitleView() -> UIStackView {
        titleAvatar.contentMode = .scaleAspectFill
        titleAvatar.mas_makeConstraints { make in
            make?.width.height().mas_equalTo()(36)
        }
        titleAvatar.layer.cornerRadius = 18
        titleAvatar.layer.masksToBounds = true
        let stackView = UIStackView(arrangedSubviews: [titleLabel, titleAvatar])
        stackView.spacing = 2
        updateTitleAvatar()
        return stackView
    }
    
    func updateTitleAvatar() {
        let block: (Data) -> Void = { [self] data in
            if friend.avatarURL.hasSuffix(".gif") {
                titleAvatar.animatedImage = FLAnimatedImage(gifData: data)
            } else {
                titleAvatar.image = UIImage(data: data)
            }
        }
        if let cached = ContactTableViewCell.avatarCache[friend.avatarURL] {
            block(cached)
        } else {
            MediaLoader.shared.requestImage(urlStr: friend.avatarURL, type: .image, cookie: self.manager.cookie, syncIfCan: true, completion: { _, data, _ in
                if let data = data {
                    block(data)
                }
            }, progress: nil)
        }
    }
    
    func makeDetailRightBarButton() {
        let barButtonItem: UIBarButtonItem
        if friend.isGroup {
            barButtonItem = UIBarButtonItem(customView: makeTitleView())
            titleAvatar.isUserInteractionEnabled = true
            titleAvatar.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(detailButtonAction(sender:))))
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressRightButton(sender:)))
            longPress.minimumPressDuration = 0.2
            titleAvatar.addGestureRecognizer(longPress)
        } else {
            barButtonItem = UIBarButtonItem(title: "···", style: .plain, target: self, action: #selector(detailButtonAction(sender:)))
        }
        self.navigationItem.setRightBarButton(barButtonItem, animated: true)
    }
    
    @objc func detailButtonAction(sender: UIBarButtonItem) {
        let vc = FriendDetailViewController(friend: friend, username: username)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc func longPressRightButton(sender: UILongPressGestureRecognizer!) {
        if sender.state == .began {
            playHaptic()
        }
        guard sender.state == .ended else {
            return
        }
        let browser = MediaBrowserViewController()
        browser.imagePaths = [self.friendAvatarUrl]
        self.splitViewController?.present(browser, animated: true, completion: nil)
        playHaptic()
    }
    
    @objc func groupInfoChange(noti: Notification) {
        let group = noti.userInfo?["group"] as! Group
        guard group.userID == self.friend.userID else { return }
        customTitle = group.username
        updateTitleAvatar()
    }
}
