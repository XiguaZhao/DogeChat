//
//  ContactsTableViewController+Avatar.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/5.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation
import SwiftyJSON
import DogeChatNetwork

extension ContactsTableViewController: ContactTableViewCellDelegate, UIContextMenuInteractionDelegate {
    func avatarTapped(_ cell: ContactTableViewCell?, path: String) {
        let browser = ImageBrowserViewController()
        browser.modalPresentationStyle = .fullScreen
        browser.imagePaths = [WebSocketManager.url_pre + path]
        appDelegate.navigationController.present(browser, animated: true, completion: nil)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        DispatchQueue.main.async {
            self.setupMyAvatar()
        }
    }
    
    func setupMyAvatar() {
        let label = UILabel()
        label.text = self.username
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.layer.masksToBounds = true
        if let navBar = self.navigationController?.navigationBar {
            avatarImageView.layer.cornerRadius = navBar.bounds.height / 2
        } else {
            avatarImageView.layer.cornerRadius = 44 / 2
        }
        let stackView = UIStackView(arrangedSubviews: [avatarImageView, label])
        stackView.spacing = 15
        if #available(iOS 13.0, *) {
            let interaction = UIContextMenuInteraction(delegate: self)
            stackView.addInteraction(interaction)
        }
        self.navigationItem.titleView = stackView
        avatarImageView.mas_updateConstraints { [weak self] make in
            make?.width.mas_equalTo()(self?.avatarImageView.mas_height)
            
        }
        stackView.isUserInteractionEnabled = true
        let tapAvatar = UITapGestureRecognizer(target: self, action: #selector(changeAvatarAction(_:)))
        stackView.addGestureRecognizer(tapAvatar)
    }
    
    @available(iOS 13.0, *)
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        return .init(identifier: nil) { [weak self] in
            guard let self = self else { return nil }
            let browser = ImageBrowserViewController()
            browser.imagePaths = [self.manager.messageManager.myAvatarUrl]
            return browser
        } actionProvider: { _ in
            return nil
        }
    }
        
    @objc func updateMyAvatar(_ noti: Notification) {
        let url = noti.userInfo?["path"] as! String
        SDWebImageManager.shared.loadImage(with: URL(string: url), options: [.avoidDecodeImage, .allowInvalidSSLCertificates], progress: nil) { [self] image, data, error, _, _, _ in
            if url.hasSuffix(".gif") {
                if let data = data {
                    avatarImageView.animatedImage = FLAnimatedImage(gifData: data)
                    ContactTableViewCell.avatarCache[url] = data
                }
            } else {
                if let image = image {
                    let data = compressEmojis(image)
                    avatarImageView.image = UIImage(data: data)
                    ContactTableViewCell.avatarCache[url] = data
                }
            }
            if let chatVC = navigationController?.visibleViewController as? ChatRoomViewController {
                chatVC.tableView.reloadData()
            }
        }
    }
    
    @objc func friendChangeAvatar(_ noti: Notification) {
        let data = noti.userInfo?["data"] as! JSON
        let username = data["username"].stringValue
        let newAvatarUrl = data["avatarUrl"].stringValue
        if let index = self.usersInfos.firstIndex(where: { $0.name == username }) {
            self.usersInfos[index].avatarUrl = newAvatarUrl
            tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
            if let chatVC = AppDelegate.shared.navigationController.visibleViewController as? ChatRoomViewController {
                if chatVC.navigationItem.title == username {
                    chatVC.tableView.reloadData()
                } else if chatVC.navigationItem.title == "群聊" {
                    let allMessage = chatVC.messages
                    let messagesWhoChangeAvatar = allMessage.filter { $0.senderUsername == username }
                    for message in messagesWhoChangeAvatar {
                        message.avatarUrl = WebSocketManager.url_pre + newAvatarUrl
                    }
                    chatVC.tableView.reloadData()
                }
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
