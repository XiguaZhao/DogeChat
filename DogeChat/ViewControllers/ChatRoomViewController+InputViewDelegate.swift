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
import SwiftyJSON
import DogeChatNetwork

extension ChatRoomViewController: MessageInputDelegate, VoiceRecordDelegate {
    
    func toolButtonTap(_ button: UIButton, type: InputViewToolButtonType) {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        switch type {
        case .voice:
            voiceButtonTapped(button)
        case .camera:
            imagePicker.sourceType = .camera
            imagePicker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .camera)!
            imagePicker.videoQuality = .typeIFrame1280x720
            imagePicker.cameraCaptureMode = .photo
            self.present(imagePicker, animated: true, completion: nil)
        case .photo:
            if #available(iOS 14, *) {
                var config = PHPickerConfiguration()
                config.filter = PHPickerFilter.any(of: [.images])
                config.selectionLimit = 0
                let picker = PHPickerViewController(configuration: config)
                picker.delegate = self
                self.present(picker, animated: true, completion: nil)
            } else {
                
            }
        case .livePhoto:
            if #available(iOS 14, *) {
                var config = PHPickerConfiguration()
                config.filter = PHPickerFilter.livePhotos
                config.selectionLimit = 0
                let picker = PHPickerViewController(configuration: config)
                picker.delegate = self
                self.present(picker, animated: true, completion: nil)
            } else {
                
            }
        case .video:
            if #available(iOS 14.0, *) {
                imagePicker.mediaTypes = [UTType.movie.identifier]
            } else {
                imagePicker.mediaTypes = ["public.movie"]
            }
            self.present(imagePicker, animated: true, completion: nil)
            self.messageInputBar.textView.resignFirstResponder()
        case .draw:
            if #available(iOS 14, *) {
                let drawVC = DrawViewController()
                drawVC.pkViewDelegate.dataChangedDelegate = self
                let newMessage = Message(message: "", messageSender: .ourself, receiver: self.friendName, uuid: UUID().uuidString, sender: self.username, messageType: .draw, option: self.messageOption)
                drawVC.message = newMessage
                drawVC.modalPresentationStyle = .fullScreen
                drawVC.chatRoomVC = self
                self.drawingIndexPath = IndexPath(item: self.messages.count, section: 0)
                self.navigationController?.present(drawVC, animated: true, completion: nil)
            }
        case .add:
            addButtonTapped()
        }
    }
    
    func addButtonTapped() {
        messageInputBar.textViewResign()
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let popover = actionSheet.popoverPresentationController
        popover?.sourceView = messageInputBar.addButton
        popover?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
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
        voiceVC.preferredContentSize = CGSize(width: 300, height: 250)
        let popover = voiceVC.popoverPresentationController
        popover?.sourceView = sender
        popover?.sourceRect = sender.frame
        popover?.delegate = self
        voiceVC.delegate = self
        self.present(voiceVC, animated: true, completion: nil)
    }
    
    func voiceConfirmSend(_ url: URL, duration: Int) {
        self.voiceInfo = (url, duration)
        sendVoice()
    }
    
    @available(iOS 14, *)
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        let isLivePhotoOnly = picker.configuration.filter == .livePhotos
        self.pickedLivePhotos.removeAll()
        for result in results {
            if result.itemProvider.canLoadObject(ofClass: PHLivePhoto.self) && isLivePhotoOnly {
                result.itemProvider.loadObject(ofClass: PHLivePhoto.self) {[self] livePhoto, error in
                    if let live = livePhoto as? PHLivePhoto {
                        LivePhotoGenerator().generate(for: live) { livePhoto in
                            let sel = Selector(("imageURL"))
                            let imageURL = livePhoto.perform(sel).takeUnretainedValue() as! URL
                            let videoURL = livePhoto.perform(Selector(("videoURL"))).takeUnretainedValue() as! URL
                            self.pickedLivePhotos.append((imageURL, videoURL, livePhoto.size, livePhoto))
                            if self.pickedLivePhotos.count == results.count {
                                self.sendLivePhotos()
                            }
                        }
                    }
                }
                continue
            }
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                if let image = object as? UIImage {
                    result.itemProvider.loadItem(forTypeIdentifier: UTType.gif.identifier, options: nil) { gif, error in
                        if let gifUrl = gif as? URL {
                            self?.latestPickedImageInfos.append((image, gifUrl, image.size))
                        } else {
                            self?.latestPickedImageInfos.append(WebSocketManagerAdapter.shared.compressImage(image))
                        }
                        if self?.latestPickedImageInfos.count == results.count {
                            self?.confirmSendPhoto()
                        }
                    }
                    
                }
            }
        }
    }
    
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let type = info[.mediaType] as? String, type == "public.movie" {
            if let videoURL = info[.mediaURL] as? URL {
                let dir = createDir(name: videoDir)
                let uuid = UUID().uuidString
                let newURL = dir.appendingPathComponent(uuid).appendingPathExtension("mov")
                LivePhotoGenerator().compressVideo(withInputURL: videoURL, outputURL: newURL, quality: .quality540, compressType: .thirdParty) {
                    self.pickedVideos = (newURL, self.resolutionForLocalVideo(url: newURL) ?? .zero)
                    self.sendVideo()
                }
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
        if let originalUrl_ = info[.imageURL] as? URL {
            isGif = originalUrl_.absoluteString.hasSuffix(".gif")
            originalUrl = originalUrl_
        }
        self.latestPickedImageInfos = [(isGif ? (nil, originalUrl!, image.size) : WebSocketManagerAdapter.shared.compressImage(image))]
        picker.dismiss(animated: true) {
            guard !isGif else {
                self.confirmSendPhoto()
                return
            }
            let vc = ImageConfirmViewController()
            if let image = self.latestPickedImageInfos.first?.image {
                vc.image = image
            } else {
                vc.image = image
            }
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @objc func confirmSendPhoto() {
        let infos = self.latestPickedImageInfos
        var newMessages = [Message]()
        for (_, imageURL, size) in infos {
            let message = Message(message: "", imageURL: imageURL.absoluteString, videoURL: nil, messageSender: .ourself, receiver: friendName, sender: username, messageType: .image, option: messageOption, sendStatus: .fail)
            message.imageSize = size
            manager.messageManager.imageDict[message.uuid] = imageURL
            newMessages.append(message)
            manager.uploadPhoto(imageUrl: imageURL, message: message, size: size) { progress in
                
            } success: { task, data in
                let json = JSON(data as Any)
                var filePath = json["filePath"].stringValue
                filePath = WebSocketManager.shared.messageManager.encrypt.decryptMessage(filePath)
                message.imageURL = filePath
                message.message = message.imageURL ?? ""
                message.imageLocalPath = imageURL
                NotificationCenter.default.post(name: .uploadSuccess, object: nil, userInfo: ["message": message, "data": data ?? [:]])
                SDWebImageManager.shared.loadImage(with: URL(string: filePath), options: [.avoidDecodeImage, .allowInvalidSSLCertificates], progress: nil) { _, _, _, _, _, _ in
                    
                }
            }
        }
        insertNewMessageCell(newMessages, forceScrollBottom: true)
        self.latestPickedImageInfos.removeAll()
    }

    private func resolutionForLocalVideo(url: URL) -> CGSize? {
        guard let track = AVURLAsset(url: url).tracks(withMediaType: AVMediaType.video).first else { return nil }
        let size = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(size.width), height: abs(size.height))
    }
    
    func sendVoice() {
        defer {
            self.voiceInfo = nil
        }
        guard let info = self.voiceInfo else { return }
        let message = Message(message: "", messageSender: .ourself, sender: myName, messageType: .voice)
        message.receiver = friendName
        message.voiceLocalPath = info.url
        message.voiceDuration = info.duration
        message.sendStatus = .fail
        WebSocketManager.shared.uploadPhoto(imageUrl: info.url, message: message, size: .zero, voiceDuration: info.duration) { _ in
            
        } success: { task, data in
            guard let data = data as? Data else { return }
            let json = JSON(data as Any)
            var voicePath = json["filePath"].stringValue
            voicePath = WebSocketManager.shared.messageManager.encrypt.decryptMessage(voicePath)
            print(voicePath)
            message.voiceURL = voicePath
            message.message = voicePath
            NotificationCenter.default.post(name: .uploadSuccess, object: nil, userInfo: ["message": message])
            DispatchQueue.global().async {
                let dir = createDir(name: voiceDir)
                let newVoiceUrl = dir.appendingPathComponent(voicePath.components(separatedBy: "/").last!)
                try? FileManager.default.moveItem(at: info.url, to: newVoiceUrl)
                message.videoLocalPath = newVoiceUrl
            }
        }
        insertNewMessageCell([message], forceScrollBottom: true)
    }
    
    func sendVideo() {
        defer {
            self.pickedVideos = nil
        }
        guard let info = self.pickedVideos else { return }
        let message = Message(message: "", messageSender: .ourself, sender: myName, messageType: .video)
        message.videoLocalPath = info.url
        message.receiver = friendName
        message.imageSize = info.size
        message.sendStatus = .fail
        WebSocketManager.shared.uploadPhoto(imageUrl: info.url, message: message, size: info.size) { _ in
            
        } success: { task, data in
            guard let data = data as? Data else { return }
            let json = JSON(data as Any)
            var videoPath = json["filePath"].stringValue
            videoPath = WebSocketManager.shared.messageManager.encrypt.decryptMessage(videoPath)
            print(videoPath)
            message.message = videoPath
            message.videoURL = videoPath
            NotificationCenter.default.post(name: .uploadSuccess, object: nil, userInfo: ["message": message])
            DispatchQueue.global().async {
                let dir = createDir(name: videoDir)
                let newVideoUrl = dir.appendingPathComponent(videoPath.components(separatedBy: "/").last!)
                try? FileManager.default.moveItem(at: info.url, to: newVideoUrl)
                message.videoLocalPath = newVideoUrl
            }
        }
        insertNewMessageCell([message], forceScrollBottom: true)
    }
    
    func sendLivePhotos() {
        var newMessages = [Message]()
        for livePhoto in pickedLivePhotos {
            let message = Message(message: "", messageSender: .ourself, sender: myName, messageType: .livePhoto)
            message.imageURL = livePhoto.imageURL.absoluteString
            message.videoURL = livePhoto.videoURL.absoluteString
            message.receiver = friendName
            message.livePhoto = livePhoto.live
            message.imageSize = livePhoto.size
            message.sendStatus = .fail
            newMessages.append(message)
            WebSocketManager.shared.uploadPhoto(imageUrl: livePhoto.imageURL, message: message, size: livePhoto.size) { _ in
                
            } success: { task, data in
                let json = JSON(data as Any)
                var imagePath = json["filePath"].stringValue
                imagePath = WebSocketManager.shared.messageManager.encrypt.decryptMessage(imagePath)
                print(imagePath)
                WebSocketManager.shared.uploadPhoto(imageUrl: livePhoto.videoURL, message: message, size: livePhoto.size) { _ in
                    
                } success: { task, data in
                    let json = JSON(data as Any)
                    var videoPath = json["filePath"].stringValue
                    videoPath = WebSocketManager.shared.messageManager.encrypt.decryptMessage(videoPath)
                    print(videoPath)
                    message.imageURL = imagePath
                    message.videoURL = videoPath
                    message.message = imagePath + " " + videoPath
                    NotificationCenter.default.post(name: .uploadSuccess, object: nil, userInfo: ["message": message])
                    DispatchQueue.global().async {
                        let dir = createDir(name: livePhotoDir)
                        let newImageUrl = dir.appendingPathComponent(imagePath.components(separatedBy: "/").last!)
                        let newVideoUrl = dir.appendingPathComponent(videoPath.components(separatedBy: "/").last!)
                        try? FileManager.default.moveItem(at: livePhoto.imageURL, to: newImageUrl)
                        try? FileManager.default.moveItem(at: livePhoto.videoURL, to: newVideoUrl)
                    }
                }
            }
        }
        insertNewMessageCell(newMessages)
        pickedLivePhotos.removeAll()
    }
    
    

}
