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
        let tapAvatar = UITapGestureRecognizer(target: self, action: #selector(changeAvatarAction(_:)))
        stackView.addGestureRecognizer(tapAvatar)
    }
    
    @objc func longPressRightButton(sender: UILongPressGestureRecognizer!) {
        if sender.state == .began {
            playHaptic()
        }
        guard sender.state == .ended else {
            return
        }
        let browser = MediaBrowserViewController()
        browser.imagePaths = [manager.messageManager.myAvatarUrl]
        self.splitViewController?.present(browser, animated: true, completion: nil)
        playHaptic()
    }
    
    @available(iOS 13.0, *)
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        return .init(identifier: nil) { [weak self] in
            guard let self = self else { return nil }
            let browser = MediaBrowserViewController()
            browser.imagePaths = [self.manager.messageManager.myAvatarUrl]
            return browser
        } actionProvider: { _ in
            return nil
        }
    }
        
    @objc func updateMyAvatar(_ noti: Notification) {
        let url = noti.userInfo?["path"] as! String
        MediaLoader.shared.requestImage(urlStr: url, type: .image, cookie: manager.cookie) { [self] image, data, _ in
            guard let data = data else { return }
            if url.hasSuffix(".gif") {
                avatarImageView.animatedImage = FLAnimatedImage(gifData: data)
            } else {
                avatarImageView.image = UIImage(data: data)
            }
            if let chatVC = navigationController?.visibleViewController as? ChatRoomViewController {
                chatVC.tableView.reloadData()
            }
        }
    }
    
    @objc func friendChangeAvatar(_ noti: Notification) {
        let friend = noti.userInfo?["friend"] as! Friend
        if let index = self.friends.firstIndex(of: friend) {
            self.friends[index].avatarURL = friend.avatarURL
            tableView.reloadData()
            if let chatVC = findChatRoomVC() {
                for message in chatVC.messages where message.senderUserID == friend.userID {
                    message.avatarUrl = friend.avatarURL
                }
                chatVC.tableView.reloadData()
            }
        }
    }
    
    @objc func changeAvatarAction(_ tap: UITapGestureRecognizer) {
        let picker = UIImagePickerController()
        picker.allowsEditing = true
        picker.delegate = self
        self.present(picker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let image = info[.editedImage] as? UIImage else { return }
        if let compressedImageData = compressImage(image, needSave: false).image.jpegData(compressionQuality: 0.3) {
            manager.uploadData(compressedImageData, path: "user/changeAvatar", name: "avatar", fileName: UUID().uuidString + ".jpeg", needCookie: true, contentType: "multipart/form-data", params: nil) { [weak self] task, data in
                guard let self = self, let data = data else { return }
                let json = JSON(data)
                if json["status"].stringValue == "success" {
                    self.manager.messageManager.myAvatarUrl = WebSocketManager.url_pre + json["avatarUrl"].stringValue
                }
            }
        }
    }
    

}
