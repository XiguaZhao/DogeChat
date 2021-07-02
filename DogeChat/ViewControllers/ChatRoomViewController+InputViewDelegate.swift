//
//  ChatRoomViewController+InputViewDelegate.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/20.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation
import PhotosUI
import DogeChatUniversal

extension ChatRoomViewController: MessageInputDelegate, UIPopoverPresentationControllerDelegate {
    
    func addButtonTapped() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        messageInputBar.textView.resignFirstResponder()
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let popover = actionSheet.popoverPresentationController
        popover?.sourceView = messageInputBar.addButton
        popover?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        actionSheet.addAction(UIAlertAction(title: "拍照/视频", style: .default, handler: { [weak self] (action) in
            imagePicker.sourceType = .camera
            imagePicker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .camera)!
            imagePicker.videoQuality = .typeIFrame1280x720
            imagePicker.cameraCaptureMode = .photo
            self?.present(imagePicker, animated: true, completion: nil)
        }))
        actionSheet.addAction(UIAlertAction(title: "从相册选择", style: .default, handler: { [weak self] (action) in
            self?.present(imagePicker, animated: true, completion: nil)
            self?.messageInputBar.textView.resignFirstResponder()
        }))
        if #available(iOS 14.0, *) {
            actionSheet.addAction(UIAlertAction(title: "相册（多选，不支持gif）", style: .default, handler: { [weak self] _ in
                var config = PHPickerConfiguration()
                config.selectionLimit = 0
                let picker = PHPickerViewController(configuration: config)
                picker.delegate = self
                self?.present(picker, animated: true, completion: nil)
            }))
        }
        let startCallAction = { [weak self] in
            guard let self = self else { return }
            let uuid = UUID().uuidString
            self.manager.sendCallRequst(to: self.friendName, uuid: uuid)
            AppDelegate.shared.callManager.startCall(handle: self.friendName, uuid: uuid)
        }
        actionSheet.addAction(UIAlertAction(title: "语音通话", style: .default, handler: {  (action) in
            startCallAction()
        }))
        actionSheet.addAction(UIAlertAction(title: "视频通话", style: .default, handler: { (action) in
            startCallAction()
            Recorder.sharedInstance().needSendVideo = true
        }))
        if #available(iOS 14.0, *) {
            actionSheet.addAction(UIAlertAction(title: "速绘", style: .default, handler: { [weak self] (action) in
                guard let self = self else { return }
                let drawVC = DrawViewController()
                drawVC.pkViewDelegate.dataChangedDelegate = self
                let newMessage = Message(message: "", messageSender: .ourself, receiver: self.friendName, uuid: UUID().uuidString, sender: self.username, messageType: .draw, option: self.messageOption)
                drawVC.message = newMessage
                drawVC.modalPresentationStyle = .fullScreen
                self.drawingIndexPath = IndexPath(item: self.messages.count, section: 0)
                self.navigationController?.present(drawVC, animated: true, completion: nil)
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
        textViewDidChange(textView)
    }
    
    func textViewFontSizeChangeEnded(_ textView: UITextView) {
        textViewDidChange(textView)
    }
    
    func voiceButtonTapped(_ sender: UIButton) {
        let voiceVC = VoiceViewController()
        voiceVC.modalPresentationStyle = .popover
        voiceVC.preferredContentSize = CGSize(width: 350, height: 350)
        let popover = voiceVC.popoverPresentationController
        popover?.sourceView = sender
        popover?.sourceRect = sender.frame
        popover?.delegate = self
        self.present(voiceVC, animated: true, completion: nil)
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}
