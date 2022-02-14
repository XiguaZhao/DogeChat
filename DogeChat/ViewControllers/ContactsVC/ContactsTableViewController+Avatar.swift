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
import DogeChatCommonDefines

extension ContactsTableViewController: ContactTableViewCellDelegate, UIContextMenuInteractionDelegate, TransitionFromDataSource, TransitionToDataSource {
    
    func avatarTapped(_ cell: ContactTableViewCell?, path: String) {
        self.makeBrowser(paths: [path], targetIndex: 0, purpose: .avatar)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        DispatchQueue.main.async {
            self.setupMyAvatar()
        }
    }
    
    func createMyAvatar() {
        nameLabel.font = .boldSystemFont(ofSize: 17)
        nameLabel.text = self.username
        avatarImageView.contentMode = .scaleAspectFill
        avatarContainer.layer.masksToBounds = true
        avatarContainer.layer.cornerRadius = 22;
        avatarContainer.addSubview(avatarImageView)
        let stackView = UIStackView(arrangedSubviews: [avatarContainer, nameLabel])
        stackView.spacing = 10
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressRightButton(sender:)))
        longPress.minimumPressDuration = 0.2
        stackView.addGestureRecognizer(longPress)
        self.navigationItem.titleView = stackView
        
        stackView.isUserInteractionEnabled = true
        let tapAvatar = UITapGestureRecognizer(target: self, action: #selector(titleViewTap(_:)))
        stackView.addGestureRecognizer(tapAvatar)

    }
    
    func setupMyAvatar() {
        DispatchQueue.main.async { [self] in
            if let bar = navigationController?.navigationBar {
                avatarContainer.layer.cornerRadius = bar.bounds.height / 2
                avatarContainer.mas_updateConstraints { make in
                    make?.width.height().mas_equalTo()(bar.bounds.height)
                }
            }
        }
        if let url = manager?.httpsManager.accountInfo.avatarURL, !url.isEmpty {
            updateMyAvatar(url: url, force: true)
        }
    }
    
    @objc func longPressRightButton(sender: UILongPressGestureRecognizer!) {
        if sender.state == .began {
            playHaptic()
        }
        guard let manager = manager, sender.state == .ended else {
            return
        }
        self.transitionSourceView = avatarImageView
        self.transitionToView = avatarImageView
        self.transitionToRadiusView = avatarContainer
        self.transitionFromCornerRadiusView = avatarContainer
        let browser = MediaBrowserViewController()
        browser.imagePaths = [manager.httpsManager.myAvatarUrl]
        browser.purpose = .avatar
        browser.modalPresentationStyle = .fullScreen
        browser.transitioningDelegate = DogeChatTransitionManager.shared
        DogeChatTransitionManager.shared.fromDataSource = self
        DogeChatTransitionManager.shared.toDataSource = self
        self.present(browser, animated: true, completion: nil)

        playHaptic()
    }
        
    @available(iOS 13.0, *)
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
    
    func updateMyAvatar(url: String, force: Bool = false) {
        if !force && self.lastAvatarURL == url && (avatarImageView.image != nil || avatarImageView.animatedImage != nil) { return }
        lastAvatarURL = url
        DispatchQueue.main.async { [self] in
            let height = self.navigationController?.navigationBar.bounds.height ?? 44
            let finalSize: CGSize
            if let size = sizeFromStr(url), let avatarSize = sizeFromStr(url, preferWidth: size.width < size.height, length: height) {
                finalSize = avatarSize
            } else {
                finalSize = CGSize(width: height, height: height)
            }
            avatarImageView.mas_updateConstraints { make in
                make?.centerX.centerY().equalTo()(avatarContainer)
                make?.width.mas_equalTo()(finalSize.width)
                make?.height.mas_equalTo()(finalSize.height)
            }
        }
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
        }
    }
    
    @objc func titleViewTap(_ tap: UITapGestureRecognizer) {
        self.navigationController?.setViewControllersForSplitVC(vcs: [self, ProfileVC()])
    }
        

}
