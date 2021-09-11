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
                drawVC.username = username
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
        if !isMac() {
            actionSheet.addAction(UIAlertAction(title: "语音通话", style: .default, handler: {  (action) in
                startCallAction()
            }))
            actionSheet.addAction(UIAlertAction(title: "视频通话", style: .default, handler: { (action) in
                startCallAction()
                Recorder.sharedInstance().needSendVideo = true
            }))
        }
        if #available(iOS 13.0, *) {
            actionSheet.addAction(UIAlertAction(title: "历史记录", style: .default, handler: { [weak self] (action) in
                guard let self = self else { return }
                let vc = HistoryVC()
                vc.option = self.messageOption
                vc.name = self.friendName
                vc.cache = self.cache
                vc.username = self.username
                self.navigationController?.pushViewController(vc, animated: true)
            }))
        }
        actionSheet.addAction(UIAlertAction(title: "Music", style: .default, handler: { [weak self] _ in
            self?.shareMusic()
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
        self.voiceInfo = (url, duration)
        sendVoice()
    }
    
    @available(iOS 14, *)
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        if results.isEmpty { return }
        let isLivePhotoOnly = picker.configuration.filter == .livePhotos
        self.pickedLivePhotos.removeAll()
        if isLivePhotoOnly {
            let alert = makeAlert(message: "正在压缩" + "0/\(results.count)")
            present(alert, animated: true, completion: nil)
            for result in results {
                if result.itemProvider.canLoadObject(ofClass: PHLivePhoto.self) {
                    result.itemProvider.loadObject(ofClass: PHLivePhoto.self) {[self] livePhoto, error in
                        if let live = livePhoto as? PHLivePhoto {
                            alert.title = "正在压缩" + "0/\(results.count)"
                            LivePhotoGenerator().generate(for: live, windowWidth: AppDelegate.shared.widthFor(side: .right, username: self.username)) { livePhoto in
                                let sel = Selector(("imageURL"))
                                let imageURL = livePhoto.perform(sel).takeUnretainedValue() as! URL
                                let videoURL = livePhoto.perform(Selector(("videoURL"))).takeUnretainedValue() as! URL
                                self.pickedLivePhotos.append((imageURL, videoURL, livePhoto.size, livePhoto))
                                alert.title = "正在压缩" + "\(self.pickedLivePhotos.count)/\(results.count)"
                                if self.pickedLivePhotos.count == results.count {
                                    alert.dismiss(animated: true) {
                                        self.sendLivePhotos()
                                    }
                                }
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
        for item in items {
            item.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                if let image = object as? UIImage {
                    if #available(iOS 14.0, *) {
                        item.loadItem(forTypeIdentifier: UTType.gif.identifier, options: nil) { gif, error in
                            if var gifUrl = gif as? URL {
                                if !gifUrl.absoluteString.hasSuffix(".gif") { //从剪贴板过来的
                                    let newURL = createDir(name: pasteDir).appendingPathComponent(UUID().uuidString).appendingPathExtension("gif")
                                    let _ = gifUrl.startAccessingSecurityScopedResource()
                                    try? FileManager.default.copyItem(at: gifUrl, to: newURL)
                                    gifUrl.stopAccessingSecurityScopedResource()
                                    gifUrl = newURL
                                }
                                if let success = try? gifUrl.checkResourceIsReachable(), success {
                                    self?.latestPickedImageInfos.append((image, gifUrl, image.size))
                                } else {
                                    self?.latestPickedImageInfos.append(WebSocketManagerAdapter.shared.compressImage(image))
                                }
                            } else {
                                self?.latestPickedImageInfos.append(WebSocketManagerAdapter.shared.compressImage(image))
                            }
                            if self?.latestPickedImageInfos.count == items.count {
                                self?.confirmSendPhoto()
                            }
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
    
    private func resolutionForLocalVideo(url: URL) -> CGSize? {
        guard let track = AVURLAsset(url: url).tracks(withMediaType: AVMediaType.video).first else { return nil }
        let size = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(size.width), height: abs(size.height))
    }

}
