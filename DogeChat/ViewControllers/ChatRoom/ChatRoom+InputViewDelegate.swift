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
import DogeChatCommonDefines

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
            pickerPurpose = .send
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
            pickerPurpose = .send
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
            if #available(iOS 13.0, *) {
                let drawVC = DrawViewController()
                drawVC.username = username
                drawVC.pkViewDelegate.dataChangeDelegate = self
                let newMessage = processMessageString(for: "", type: .draw, imageURL: nil, videoURL: nil)
                drawVC.message = newMessage
                drawVC.modalPresentationStyle = .fullScreen
                drawVC.chatRoomVC = self
                self.navigationController?.present(drawVC, animated: true, completion: nil)
            }
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
            let selectVC = SelectContactsViewController(username: self.username, group: group, members: self.groupMembers)
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
            if #available(iOS 13.0, *) {
                SceneDelegate.usernameToDelegate[self.username]?.callManager.startCall(handle: self.friendName, uuid: uuid)
            }
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
        popover?.sourceRect = sender.bounds
        popover?.delegate = self
        voiceVC.delegate = self
        self.present(voiceVC, animated: true, completion: nil)
    }
    
    func voiceConfirmSend(_ url: URL, duration: Int) {
        self.messageSender.voiceInfo = (url, duration)
        _ = self.messageSender.sendVoice(friends: [friend])
    }
        
    func processItemProviders(_ items: [NSItemProvider]) {
        messageSender.processItemProviders(items, friends: [self.friend]) { messages in
            self.insertNewMessageCell(messages)
        }
    }
        
}
