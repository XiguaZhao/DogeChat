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
import DogeChatCommonDefines

extension ChatRoomViewController {
    
    @available(iOS 13.0, *)
    func addItemForSingle() {
        if self.sceneType == .single {
            let item = UIBarButtonItem(title: "关闭", style: .done, target: self, action: #selector(doneWithSingle))
            self.navigationItem.leftBarButtonItem = item
        }
        if self.sceneType == .normal && UIApplication.shared.supportsMultipleScenes {
            let item = UIBarButtonItem(image: UIImage(systemName: "rectangle.portrait.split.2x1"), style: .plain, target: self, action: #selector(openNewScene))
            var items = [item]
            if let detailItem = self.navigationItem.rightBarButtonItem {
                items.insert(detailItem, at: 0)
            }
            self.navigationItem.setRightBarButtonItems(items, animated: true)
        }
    }
    
    @available(iOS 13.0, *)
    @objc func openNewScene() {
        let option = UIScene.ActivationRequestOptions()
        option.requestingScene = self.view.window?.windowScene
        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: self.contactVC?.wrapUserActivity(for: self.friend), options: option, errorHandler: nil)
    }
    
    
    @available(iOS 13.0, *)
    @objc func doneWithSingle() {
        if let session = self.view.window?.windowScene?.session {
            let option = UIWindowSceneDestructionRequestOptions()
            option.windowDismissalAnimation = .commit
            UIApplication.shared.requestSceneSessionDestruction(session, options: option, errorHandler: nil)
        }
    }
    
    func setupToolBar() {
        let cancle = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(self.cancelItemAction))
        let share = UIBarButtonItem(title: "转发", style: .plain, target: self, action: #selector(self.didFinishMultiSelection(_:)))
        self.toolbarItems = [cancle, share]
        if #available(iOS 14.0, *) {
            let flex = UIBarButtonItem.flexibleSpace()
            self.toolbarItems = [flex, cancle, share, flex]
        }
        messageInputBar.isHidden = true
        navigationController?.setToolbarHidden(false, animated: true)
    }
    
    func recoverInputBar() {
        self.navigationController?.setToolbarHidden(true, animated: true)
        messageInputBar.isHidden = false
    }
    
    func makeTitleView() -> UIStackView {
        titleAvatarContainer.addSubview(titleAvatar)
        titleAvatar.contentMode = .scaleAspectFill
        titleAvatarContainer.mas_makeConstraints { make in
            make?.width.height().mas_equalTo()(36)
        }
        let finalSize: CGSize
        let width: CGFloat = 36
        if let size = sizeFromStr(friendAvatarUrl), let avatarSize = sizeFromStr(friendAvatarUrl, preferWidth: size.width < size.height, length: width) {
            finalSize = avatarSize
        } else {
            finalSize = CGSize(width: width, height: width)
        }
        titleAvatar.mas_makeConstraints { make in
            make?.centerX.centerY().equalTo()(titleAvatarContainer)
            make?.width.mas_equalTo()(finalSize.width)
            make?.height.mas_equalTo()(finalSize.height)
        }
        titleAvatarContainer.layer.cornerRadius = 18
        titleAvatarContainer.layer.masksToBounds = true
        let stackView = UIStackView(arrangedSubviews: [titleLabel, titleAvatarContainer])
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
        MediaLoader.shared.requestImage(urlStr: friend.avatarURL, type: .image, cookie: self.manager?.cookie, syncIfCan: true, completion: { _, data, _ in
            if let data = data {
                block(data)
            }
        }, progress: nil)
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
        playHaptic()
        let browser = MediaBrowserViewController()
        browser.imagePaths = [self.friendAvatarUrl]
        browser.purpose = .avatar
        browser.modalPresentationStyle = .fullScreen
        browser.transitioningDelegate = DogeChatTransitionManager.shared
        DogeChatTransitionManager.shared.fromDataSource = self
        DogeChatTransitionManager.shared.toDataSource = self
        self.transitionSourceView = titleAvatar
        self.transitionToView = titleAvatar
        self.transitionToRadiusView = titleAvatarContainer
        self.transitionFromCornerRadiusView = titleAvatarContainer
        self.present(browser, animated: true, completion: nil)
    }
    
    @objc func groupInfoChange(noti: Notification) {
        let group = noti.userInfo?["group"] as! Group
        guard group.userID == self.friend.userID else { return }
        customTitle = group.username
        updateTitleAvatar()
    }
}
