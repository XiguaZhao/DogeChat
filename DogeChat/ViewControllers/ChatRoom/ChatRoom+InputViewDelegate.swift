//
//  ChatRoomViewController+InputViewDelegate.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/20.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import Foundation
import PhotosUI
import DogeChatUniversal
import SwiftyJSON
import DogeChatNetwork

extension ChatRoomViewController: MessageInputDelegate, VoiceRecordDelegate {
    
    func messageInputBarFrameChange(_ endFrame: CGRect, shouldDown: Bool, ignore: Bool) {
        keyboardFrameChange(endFrame, shouldDown: shouldDown, duration: 0.3)
        self.ignoreKeyboardChange = ignore
    }
    
    func toolButtonTap(_ button: UIButton, type: InputViewToolButtonType) {
        messageInputBar.textView.resignFirstResponder()
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        switch type {
        case .voice:
            voiceButtonTapped(button)
        case .camera:
            cameraAction()
        case .photo:
            imagePickerType = .image
            if #available(iOS 14, *) {
                var config = PHPickerConfiguration()
                config.filter = PHPickerFilter.any(of: [.images])
                config.selectionLimit = 0
                let picker = PHPickerViewController(configuration: config)
                picker.delegate = self
                self.present(picker, animated: true, completion: nil)
            } else {
                self.present(imagePicker, animated: true, completion: nil)
            }
        case .livePhoto:
            imagePickerType = .livePhoto
            if #available(iOS 14, *) {
                var config = PHPickerConfiguration()
                config.filter = PHPickerFilter.livePhotos
                config.selectionLimit = 0
                let picker = PHPickerViewController(configuration: config)
                picker.delegate = self
                self.present(picker, animated: true, completion: nil)
            } else {
                imagePicker.mediaTypes = ["public.image", "com.apple.live-photo"]
                self.present(imagePicker, animated: true, completion: nil)
            }
        case .video:
            imagePicker.mediaTypes = ["public.movie"]
            self.present(imagePicker, animated: true, completion: nil)
        case .draw:
            let drawVC = DrawViewController()
            drawVC.username = username
            drawVC.pkViewDelegate.dataChangedDelegate = self
            let newMessage = processMessageString(for: "", type: .draw, imageURL: nil, videoURL: nil)
            drawVC.message = newMessage
            drawVC.modalPresentationStyle = .fullScreen
            drawVC.chatRoomVC = self
            self.drawingIndexPath = IndexPath(item: self.messages.count, section: 0)
            self.navigationController?.present(drawVC, animated: true, completion: nil)
        case .add:
            addButtonTapped()
        case .location:
            locationAction()
        case .at:
            atAction()
        }
    }
    
    func atAction() {
        if let group = self.friend as? Group {
            let selectVC = SelectContactsViewController(username: self.username, group: group, members: group.membersDict?.map({$0.value}) ?? self.groupMembers)
            selectVC.delegate = self
            self.present(selectVC, animated: true, completion: nil)
        }
    }
    
    func cameraAction() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        imagePicker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .camera)!
        imagePicker.videoQuality = .typeIFrame1280x720
        imagePicker.cameraCaptureMode = .photo
        self.present(imagePicker, animated: true, completion: nil)
    }
    
    func locationAction() {
        let locationVC = LocationVC()
        locationVC.delegate = self
        self.navigationController?.pushViewController(locationVC, animated: true)
    }
        
    @objc func emojiButtonTapped() {
        emojiSelectView.collectionView.reloadData()
        manager?.getEmojis { _ in
        }
        if messageInputBar.emojiButton.image(for: .normal)?.accessibilityIdentifier == "pin" {
            messageInputBar.emojiButtonStatus = .pin
        }
        let image = UIImage(systemName: "pin.circle.fill", withConfiguration: MessageInputView.largeConfig)
        image?.accessibilityIdentifier = "pin"
        messageInputBar.emojiButton.setImage(image, for: .normal)
        
    }
    
    func addButtonTapped() {
        messageInputBar.textViewResign()
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let popover = actionSheet.popoverPresentationController
        popover?.sourceView = messageInputBar.addButton
        popover?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        popover?.permittedArrowDirections = [.down]
        let startCallAction = { [weak self] in
            guard let self = self else { return }
            let uuid = UUID().uuidString
            self.manager?.sendCallRequst(to: self.friendName, uuid: uuid)
            self.manager?.nowCallUUID = UUID(uuidString: uuid)
            SceneDelegate.usernameToDelegate[self.username]?.callManager.startCall(handle: self.friendName, uuid: uuid)
        }
        if !friend.isGroup {
            actionSheet.addAction(UIAlertAction(title: "语音通话", style: .default, handler: {  (action) in
                startCallAction()
            }))
            if debugUsers.contains(self.username) {
                actionSheet.addAction(UIAlertAction(title: "视频通话", style: .default, handler: { (action) in
                    startCallAction()
                    Recorder.sharedInstance().needSendVideo = true
                }))
            }
        }
        actionSheet.addAction(UIAlertAction(title: "Tracks Preview", style: .default, handler: { [weak self] _ in
            self?.shareMusic()
        }))
        if messageInputBar.locationButton.isHidden {
            actionSheet.addAction(UIAlertAction(title: "分享定位", style: .default, handler: { [weak self] _ in
                self?.locationAction()
            }))
        }
        if messageInputBar.cameraButton.isHidden {
            actionSheet.addAction(UIAlertAction(title: "拍照/录像", style: .default, handler: { [weak self] _ in
                self?.cameraAction()
            }))
        }
        actionSheet.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        present(actionSheet, animated: true, completion: nil)
    }
    
    func textViewFontSizeChange(_ textView: UITextView, oldSize: CGFloat, newSize: CGFloat) {
        hapticIndex += 1
        guard let fontSize = textView.font?.pointSize, hapticIndex % 5 == 0, oldSize != newSize else { return }
        var intensity = fontSize / 50
        intensity = max(0.2, intensity)
        playHaptic(intensity)
    }
    
    func textViewFontSizeChangeEnded(_ textView: UITextView) {
        textViewDidChange(textView)
    }
    
    @objc func pasteImageAction(_ noti: Notification) {
        guard let item = noti.userInfo?["itemProvider"] as? NSItemProvider else { return }
        processItemProviders([item])
    }
    
    func shareMusic() {
        let vc = PlayListViewController()
        vc.username = username
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func voiceButtonTapped(_ sender: UIButton) {
        let voiceVC = VoiceViewController()
        voiceVC.modalPresentationStyle = .popover
        voiceVC.preferredContentSize = CGSize(width: 300, height: 250)
        let popover = voiceVC.popoverPresentationController
        popover?.sourceView = sender
        popover?.sourceRect = sender.frame
        popover?.delegate = self
        voiceVC.delegate = self
        self.present(voiceVC, animated: true, completion: nil)
    }
    
    func voiceConfirmSend(_ url: URL, duration: Int) {
        self.messageSender.voiceInfo = (url, duration)
        self.messageSender.sendVoice(friends: [friend])
    }
    
    @available(iOS 14, *)
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        if results.isEmpty { return }
        let isLivePhotoOnly = picker.configuration.filter == .livePhotos
        self.messageSender.pickedLivePhotos.removeAll()
        if isLivePhotoOnly {
            for result in results {
                if result.itemProvider.canLoadObject(ofClass: PHLivePhoto.self) {
                    result.itemProvider.loadObject(ofClass: PHLivePhoto.self) {[self] livePhoto, error in
                        if let live = livePhoto as? PHLivePhoto {
                            LivePhotoGenerator().generate(for: live, windowWidth: self.tableView.frame.width) { livePhoto in
                                let imageURL = livePhoto.value(forKey: "imageURL") as! URL
                                let videoURL = livePhoto.value(forKey: "videoURL") as! URL
                                self.messageSender.pickedLivePhotos = [(imageURL, videoURL, livePhoto.size, livePhoto)]
                                self.sendLivePhotos()
                            }
                        }
                    }
                    continue
                }
            }
        } else {
            processItemProviders(results.map { $0.itemProvider })
        }
    }
    
    func processItemProviders(_ items: [NSItemProvider]) {
        messageSender.processItemProviders(items, friends: [self.friend]) { messages in
            self.insertNewMessageCell(messages)
        }
    }
        
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let type = info[.mediaType] as? String, type == "public.movie" {
            if let videoURL = info[.mediaURL] as? URL {
                self.messageSender.compressAndSendVideo(videoURL, friends: [friend], completion: nil)
            }
            picker.dismiss(animated: true, completion: nil)
            return
        }
        guard let image = info[.originalImage] as? UIImage else {
            picker.dismiss(animated: true, completion: nil)
            return
        }
        var isGif = false
        var originalUrl: URL?
        if imagePickerType == .image {
            if let originalUrl_ = info[.imageURL] as? URL {
                isGif = originalUrl_.absoluteString.hasSuffix(".gif")
                originalUrl = originalUrl_
            }
            self.messageSender.latestPickedImageInfos = [(isGif ? (nil, originalUrl!, image.size) : compressImage(image))]
            picker.dismiss(animated: true) {
                guard !isGif && picker.sourceType != .camera else {
                    self.confirmSendPhoto()
                    return
                }
                let vc = ImageConfirmViewController()
                if let image = self.messageSender.latestPickedImageInfos.first?.image {
                    vc.image = image
                } else {
                    vc.image = image
                }
                self.navigationController?.pushViewController(vc, animated: true)
            }
        } else if imagePickerType == .livePhoto {
            if let live = info[.livePhoto] as? PHLivePhoto {
                LivePhotoGenerator().generate(for: live, windowWidth: self.tableView.frame.width) { livePhoto in
                    let imageURL = livePhoto.value(forKey: "imageURL") as! URL
                    let videoURL = livePhoto.value(forKey: "videoURL") as! URL
                    self.messageSender.pickedLivePhotos = [(imageURL, videoURL, livePhoto.size, livePhoto)]
                    self.sendLivePhotos()
                }
            }
        }
    }
    
    
}
