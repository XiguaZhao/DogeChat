//
//  ChatRoom+InsertMessage.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/8/31.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import DogeChatNetwork
import DogeChatUniversal
import SwiftyJSON

extension ChatRoomViewController {
    
    func insertNewMessageCell(_ messages: [Message], position: InsertPosition = .bottom, index: Int = 0, forceScrollBottom: Bool = false, completion: (()->Void)? = nil) {
        let alreadyUUIDs = self.messagesUUIDs
        let newUUIDs: Set<String> = Set(messages.map { $0.uuid })
        let filteredUUIDs = newUUIDs.subtracting(alreadyUUIDs)
        var filtered = messages.filter { filteredUUIDs.contains($0.uuid)}
        filtered = filtered.filter { message in
            if message.option != self.messageOption {
                return false
            } else if message.option == .toOne {
                if message.messageSender == .ourself {
                    return message.receiver == friendName
                } else {
                    return message.senderUsername == friendName
                }
            } else {
                return true
            }
        }
        guard !filtered.isEmpty else {
            return
        }
        var scrollToBottom = !tableView.isDragging
        let contentHeight = tableView.contentSize.height
        if contentHeight - tableView.contentOffset.y > self.view.bounds.height * 2 {
            scrollToBottom = false
        }
        scrollToBottom = scrollToBottom || (messages.count == 1 && messages[0].messageSender == .ourself)
        scrollToBottom = scrollToBottom || forceScrollBottom
        syncOnMainThread { [weak self] in
            guard let self = self else { return }
            var indexPaths: [IndexPath] = []
            for message in filtered {
                indexPaths.append(IndexPath(row: self.messages.count, section: 0))
                self.messages.append(message)
                self.messagesUUIDs.insert(message.uuid)
            }
            UIView.performWithoutAnimation {
                self.tableView.insertRows(at: indexPaths, with: .none)
            }
            needScrollToBottom = scrollToBottom
            completion?()
        }
    }
    
    // TODO: 发送文件的也需要加到未发送数组中（比如别的app拖过来这时候还没连接上）
    
    @objc func confirmSendPhoto() {
        let infos = self.latestPickedImageInfos
        var newMessages = [Message]()
        for (_, imageURL, size) in infos {
            let message = processMessageString(for: "", type: .image, imageURL: imageURL.absoluteString, videoURL: nil)
            message.imageSize = size
            manager.messageManager.imageDict[message.uuid] = imageURL
            newMessages.append(message)
            manager.uploadPhoto(imageUrl: imageURL, message: message, size: size) { [weak self] progress in
                self?.downloadProgressUpdate(progress: progress, message: message)
            } success: { [weak self] task, data in
                guard let self = self else { return }
                let json = JSON(data as Any)
                var filePath = json["filePath"].stringValue
                filePath = socketForUsername(self.username).messageManager.encrypt.decryptMessage(filePath)
                message.imageURL = filePath
                message.message = message.imageURL ?? ""
                message.imageLocalPath = imageURL
                NotificationCenter.default.post(name: .uploadSuccess, object: self.username, userInfo: ["message": message])
            }
        }
        insertNewMessageCell(newMessages, forceScrollBottom: true)
        self.latestPickedImageInfos.removeAll()
    }
    
    func sendVoice() {
        defer {
            self.voiceInfo = nil
        }
        guard let info = self.voiceInfo else { return }
        let message = processMessageString(for: "", type: .voice, imageURL: nil, videoURL: nil)
        message.voiceLocalPath = info.url
        message.voiceDuration = info.duration
        manager.uploadPhoto(imageUrl: info.url, message: message, size: .zero, voiceDuration: info.duration) { [weak self] progress in
            self?.downloadProgressUpdate(progress: progress, message: message)
        } success: { [weak self] task, data in
            guard let self = self, let data = data as? Data else { return }
            let json = JSON(data as Any)
            var voicePath = json["filePath"].stringValue
            voicePath = socketForUsername(self.username).messageManager.encrypt.decryptMessage(voicePath)
            print(voicePath)
            message.voiceURL = voicePath
            message.message = voicePath
            NotificationCenter.default.post(name: .uploadSuccess, object: self.username, userInfo: ["message": message])
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
        let message = processMessageString(for: "", type: .video, imageURL: nil, videoURL: nil)
        message.videoLocalPath = info.url
        message.receiver = friendName
        message.imageSize = info.size
        manager.uploadPhoto(imageUrl: info.url, message: message, size: info.size) { [weak self] progress in
            self?.downloadProgressUpdate(progress: progress, message: message)

        } success: { [weak self] task, data in
            guard let self = self, let data = data as? Data else { return }
            let json = JSON(data as Any)
            var videoPath = json["filePath"].stringValue
            videoPath = socketForUsername(self.username).messageManager.encrypt.decryptMessage(videoPath)
            print(videoPath)
            message.message = videoPath
            message.videoURL = videoPath
            NotificationCenter.default.post(name: .uploadSuccess, object: self.username, userInfo: ["message": message])
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
            let message = processMessageString(for: "", type: .livePhoto, imageURL: nil, videoURL: nil)
            message.imageURL = livePhoto.imageURL.absoluteString
            message.videoURL = livePhoto.videoURL.absoluteString
            message.livePhoto = livePhoto.live
            message.imageSize = livePhoto.size
            newMessages.append(message)
            manager.uploadPhoto(imageUrl: livePhoto.imageURL, message: message, size: livePhoto.size) { _ in
                
            } success: { [weak self] task, data in
                guard let self = self else { return }
                let json = JSON(data as Any)
                var imagePath = json["filePath"].stringValue
                imagePath = socketForUsername(self.username).messageManager.encrypt.decryptMessage(imagePath)
                print(imagePath)
                self.manager.uploadPhoto(imageUrl: livePhoto.videoURL, message: message, size: livePhoto.size) { [weak self] progress in
                    self?.downloadProgressUpdate(progress: progress, message: message)
                } success: { [weak self] task, data in
                    guard let self = self else { return }
                    let json = JSON(data as Any)
                    var videoPath = json["filePath"].stringValue
                    videoPath = socketForUsername(self.username).messageManager.encrypt.decryptMessage(videoPath)
                    print(videoPath)
                    message.imageURL = imagePath
                    message.videoURL = videoPath
                    message.message = imagePath + " " + videoPath
                    NotificationCenter.default.post(name: .uploadSuccess, object: self.username, userInfo: ["message": message])
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
