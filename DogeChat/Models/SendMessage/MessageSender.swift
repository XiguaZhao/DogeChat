//
//  MessageSender.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/12/29.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation
import DogeChatUniversal
import SwiftyJSON
import Photos
import DogeChatVideoUtil
import DogeChatCommonDefines

protocol ReferMessageDataSource: AnyObject {
    func referMessage() -> Message?
}

protocol DownloadUploadProgressDelegate: AnyObject {
    func downloadProgressUpdate(progress: Double, messages: [Message])
    func processingMedia(finished: Bool)
}

protocol KeyProvider: AnyObject {
    func getClientPublicKey() -> String?
}

class MessageSender {
    
    enum MessageSenderType {
        case normal
        case shareExtension
    }
            
    var latestPickedImageInfos: [(image: UIImage?, fileUrl: URL, size: CGSize)] = []
    var pickedLivePhotos: [(imageURL: URL, videoURL: URL, size: CGSize, live: PHLivePhoto)] = []
    var pickedVideos: (url: URL, size: CGSize)?
    var voiceInfo: (url: URL, duration: Int)?
    var type: MessageSenderType = .normal
    
    var at: [String : String] = [:]
    
    var manager: HttpRequestsManager?
    
    weak var progressDelegate: DownloadUploadProgressDelegate?
    weak var referMessageDataSource: ReferMessageDataSource?
    weak var clientKeyProvider: KeyProvider?
    
    func processMessageString(for string: String, type: MessageType, friend: Friend, fontSize: CGFloat = 17, imageURL: String?, videoURL: String?) -> Message? {
        guard let manager = manager else {
            return nil
        }
        let message = Message(message: string,
                              friend: friend,
                              imageURL: imageURL,
                              videoURL: videoURL,
                              messageSender: .ourself,
                              receiver: friend.username,
                              receiverUserID: friend.userID,
                              sender: manager.myName,
                              senderUserID: manager.myId,
                              messageType: type,
                              sendStatus: .fail,
                              fontSize: fontSize)
        message.referMessage = self.referMessageDataSource?.referMessage()
//        message.lastMessage = friend.messages.last
        processAtForMessage(message)
        self.at.removeAll()
        return message
    }
    
    func processAtForMessage(_ message: Message) {
        let text = message.text
        var res = [Message.AtInfo]()
        let components = text.components(separatedBy: "@")
        var location = 0
        for (index, component) in components.enumerated() {
            if let strRange = self.at.keys.compactMap( { component.range(of: $0) } ).first {
                let range = component.toNSRange(strRange)
                let infos = "location=\(location+1)&length=\(range.length)"
                if let userID = self.at[(component as NSString).substring(with: range)] {
                    res.append((userID, infos))
                }
            }
            location += (index == 0 ? 0 : 1)
            if let strRange = component.range(of: component) {
                location += component.toNSRange(strRange).length
            }
        }
        message.at = res
    }
    
    func confirmSendPhoto(friends: [Friend], emojiType: Emoji.AddEmojiType = .favorite, messageType: MessageType) -> [Message] {
        defer {
            self.latestPickedImageInfos.removeAll()
        }
        guard let manager = manager else {
            return []
        }
        let infos = self.latestPickedImageInfos
        let username = manager.myName
        var newMessages = [Message]()
        for (_, imageURL, size) in infos {
            var messagesWithSameURL = [Message]()
            for friend in friends {
                guard let message = processMessageString(for: "", type: messageType, friend: friend, imageURL: nil, videoURL: nil) else { continue }
                message.imageLocalPath = imageURL
                message.imageSize = size
                newMessages.append(message)
                messagesWithSameURL.append(message)
            }
            self.progressDelegate?.processingMedia(finished: false)
            manager.uploadPhoto(imageUrl: imageURL, type: .sticker, size: size, clientKey: self.clientKeyProvider?.getClientPublicKey()) { [weak self] progress in
                self?.progressDelegate?.downloadProgressUpdate(progress: progress.fractionCompleted, messages: messagesWithSameURL)
            } success: { [weak self] filePath in
                self?.progressDelegate?.processingMedia(finished: true)
                let dir = createDir(name: photoDir)
                let newImageLocalUrl = dir.appendingPathComponent(filePath.components(separatedBy: "/").last ?? "")
                try? FileManager.default.moveItem(at: imageURL, to: newImageLocalUrl)
                for (_, message) in messagesWithSameURL.enumerated() {
                    message.imageURL = filePath
                    message.text = message.imageURL ?? ""
                    message.imageLocalPath = newImageLocalUrl
                    NotificationCenter.default.post(name: .uploadSuccess, object: username, userInfo: ["message": message])
                }
                if messagesWithSameURL.isEmpty {
                    NotificationCenter.default.post(name: .uploadSuccess, object: username, userInfo: ["serverPath": filePath, "localURL": newImageLocalUrl, "emojiType": emojiType])
                }
            } fail: {
            }
        }
        return newMessages
    }

    func sendVoice(friends: [Friend]) -> [Message] {
        defer {
            self.voiceInfo = nil
        }
        guard let manager = manager, let info = self.voiceInfo else { return [] }
        let username = manager.myName
        let type = self.type
        var newMessages = [Message]()
        for friend in friends {
            guard let message = processMessageString(for: "", type: .voice, friend: friend, imageURL: nil, videoURL: nil) else { continue }
            message.voiceLocalPath = info.url
            message.voiceDuration = info.duration
            newMessages.append(message)
        }
        self.progressDelegate?.processingMedia(finished: false)
        manager.uploadPhoto(imageUrl: info.url, type: .voice, size: .zero, voiceDuration: info.duration, clientKey: self.clientKeyProvider?.getClientPublicKey()) { [weak self] progress in
            self?.progressDelegate?.downloadProgressUpdate(progress: progress.fractionCompleted, messages: newMessages)
        } success: { [weak self] voicePath in
            self?.progressDelegate?.processingMedia(finished: true)
            print(voicePath)
            for (index, message) in newMessages.enumerated() {
                message.voiceURL = voicePath
                message.text = voicePath
                let dir = createDir(name: voiceDir)
                let newVoiceUrl = dir.appendingPathComponent(voicePath.components(separatedBy: "/").last ?? "")
                message.videoLocalPath = newVoiceUrl
                if index == 0 && type == .normal {
                    try? FileManager.default.moveItem(at: info.url, to: newVoiceUrl)
                }
                NotificationCenter.default.post(name: .uploadSuccess, object: username, userInfo: ["message": message])
            }
        } fail: {
        }
        return newMessages
    }

    func sendVideo(friends: [Friend]) -> [Message] {
        defer {
            self.pickedVideos = nil
        }
        guard let manager = manager, let info = self.pickedVideos else { return [] }
        let username = manager.myName
        let type = self.type
        var newMessages = [Message]()
        for friend in friends {
            guard let message = processMessageString(for: "", type: .video, friend: friend, imageURL: nil, videoURL: nil) else { continue }
            message.videoLocalPath = info.url
            message.imageSize = info.size
            newMessages.append(message)
        }
        self.progressDelegate?.processingMedia(finished: false)
        manager.uploadPhoto(imageUrl: info.url, type: .video, size: info.size, clientKey: self.clientKeyProvider?.getClientPublicKey()) { [weak self] progress in
            self?.progressDelegate?.downloadProgressUpdate(progress: progress.fractionCompleted, messages: newMessages)
        } success: { [weak self] videoPath in
            self?.progressDelegate?.processingMedia(finished: true)
            print(videoPath)
            for (index, message) in newMessages.enumerated() {
                message.text = videoPath
                message.videoURL = videoPath
                DispatchQueue.global().async {
                    let dir = createDir(name: videoDir)
                    let newVideoUrl = dir.appendingPathComponent(videoPath.components(separatedBy: "/").last ?? "")
                    if index == 0 && type == .normal {
                        if Self.isMac() {
                            try? FileManager.default.copyItem(at: info.url, to: newVideoUrl)
                        } else {
                            try? FileManager.default.moveItem(at: info.url, to: newVideoUrl)
                        }
                    }
                    message.videoLocalPath = newVideoUrl
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .uploadSuccess, object: username, userInfo: ["message": message])
                    }
                }
            }
        } fail: {
        }
        return newMessages
    }
    
    func sendLivePhotos(friends: [Friend]) -> [Message] {
        defer {
            pickedLivePhotos.removeAll()
        }
        guard let manager = manager else {
            return []
        }
        let username = manager.myName
        let type = self.type
        var newMessages = [Message]()
        for livePhoto in pickedLivePhotos {
            var messageWithSameURL = [Message]()
            for friend in friends {
                guard let message = processMessageString(for: "", type: .livePhoto, friend: friend, imageURL: nil, videoURL: nil) else { continue }
                message.imageURL = livePhoto.imageURL.absoluteString
                message.videoURL = livePhoto.videoURL.absoluteString
                message.imageLocalPath = livePhoto.imageURL
                message.videoLocalPath = livePhoto.videoURL
                message.livePhoto = livePhoto.live
                message.imageSize = livePhoto.size
                newMessages.append(message)
                messageWithSameURL.append(message)
                self.progressDelegate?.processingMedia(finished: false)
                manager.uploadPhoto(imageUrl: livePhoto.imageURL, type: .livePhoto, size: livePhoto.size, clientKey: self.clientKeyProvider?.getClientPublicKey()) { _ in
                    
                } success: { [weak self] imagePath in
                    print(imagePath)
                    manager.uploadPhoto(imageUrl: livePhoto.videoURL, type: .livePhoto, size: livePhoto.size, clientKey: self?.clientKeyProvider?.getClientPublicKey()) { [weak self] progress in
                        self?.progressDelegate?.downloadProgressUpdate(progress: progress.fractionCompleted, messages: messageWithSameURL)
                    } success: { videoPath in
                        self?.progressDelegate?.processingMedia(finished: true)
                        print(videoPath)
                        for (index, message) in messageWithSameURL.enumerated() {
                            message.imageURL = imagePath
                            message.videoURL = videoPath
                            message.text = imagePath + " " + videoPath
                            DispatchQueue.global().async {
                                let dir = createDir(name: livePhotoDir)
                                let newImageUrl = dir.appendingPathComponent(imagePath.components(separatedBy: "/").last ?? "")
                                let newVideoUrl = dir.appendingPathComponent(videoPath.components(separatedBy: "/").last ?? "")
                                if index == 0 && type == .normal {
                                    try? FileManager.default.moveItem(at: livePhoto.imageURL, to: newImageUrl)
                                    try? FileManager.default.moveItem(at: livePhoto.videoURL, to: newVideoUrl)
                                }
                                DispatchQueue.main.async {
                                    NotificationCenter.default.post(name: .uploadSuccess, object: username, userInfo: ["message": message])
                                }
                            }
                        }
                    } fail: {
                    }
                } fail: {
                }
            }
        }
        return newMessages
    }

    func processItemProviders(_ items: [NSItemProvider], friends: [Friend], emojiType: Emoji.AddEmojiType = .favorite, completion: (([Message]) -> Void)? = nil, canSendData:((Any) -> Bool)? = nil) {
        for item in items {
            if item.hasItemConformingToTypeIdentifier(videoIdentifier) { // drop
                progressDelegate?.processingMedia(finished: false)
                item.loadItem(forTypeIdentifier: videoIdentifier, options: nil) { obj, error in
                    self.progressDelegate?.processingMedia(finished: true)
                    if error == nil, let url = obj as? URL, let reachable = try? url.checkResourceIsReachable(), reachable, let _ = try? Data(contentsOf: url) {
                        self.compressAndSendVideo(url, friends: friends, completion: completion)
                    } else {
                        item.loadDataRepresentation(forTypeIdentifier: videoIdentifier) { data, error in
                            if let data = data, let cacheURL = URL(string: "file://" + NSTemporaryDirectory() + UUID().uuidString + ".mov") {
                                do {
                                    try data.write(to: cacheURL)
                                    self.compressAndSendVideo(cacheURL, friends: friends, completion: completion)
                                } catch {
                                    
                                }
                            }
                        }
                    }
                }
            } else if item.hasItemConformingToTypeIdentifier(audioIdentifier) {
                self.progressDelegate?.processingMedia(finished: false)
                item.loadDataRepresentation(forTypeIdentifier: audioIdentifier) { data, error in
                    self.progressDelegate?.processingMedia(finished: true)
                    if let data = data {
                        let id = UUID().uuidString
                        let newURL = createDir(name: audioDir).appendingPathComponent(id).appendingPathExtension("m4a")
                        do {
                            try data.write(to: newURL)
                            let asset = AVURLAsset(url: newURL)
                            self.voiceInfo = (newURL, Int(CMTimeGetSeconds(asset.duration)))
                            let messages = self.sendVoice(friends: friends)
                            completion?(messages)
                        } catch {
                            
                        }
                    }
                }
            } else if item.hasItemConformingToTypeIdentifier(fileIdentifier) { // finder粘贴
                self.progressDelegate?.processingMedia(finished: false)
                item.loadItem(forTypeIdentifier: fileIdentifier, options: nil) { res, error in
                    self.progressDelegate?.processingMedia(finished: true)
                    if error == nil, let data = res as? Data, let str = String(data: data, encoding: .utf8), let url = URL(string: str) {
                        if str.isVideo {
                            self.compressAndSendVideo(url, friends: friends, completion: completion)
                        } else if str.isImage {
                            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                                self.latestPickedImageInfos = [compressImage(image)]
                                let messages = self.confirmSendPhoto(friends: friends, messageType: .photo)
                                completion?(messages)
                            }
                        }
                    }
                }
            } else if item.hasItemConformingToTypeIdentifier(gifIdentifier) {
                self.progressDelegate?.processingMedia(finished: false)
                item.loadDataRepresentation(forTypeIdentifier: gifIdentifier) { data, error in
                    self.progressDelegate?.processingMedia(finished: true)
                    if let data = data, let image = UIImage(data: data) {
                        let id = UUID().uuidString
                        let newURL = createDir(name: pasteDir).appendingPathComponent(id).appendingPathExtension("gif")
                        do {
                            try data.write(to: newURL)
                            self.latestPickedImageInfos = [(image, newURL, image.size)]
                            let messages = self.confirmSendPhoto(friends: friends, emojiType: emojiType, messageType: .sticker)
                            completion?(messages)
                        } catch {
                            
                        }
                    }
                }
            } else if item.canLoadObject(ofClass: UIImage.self) {
                self.progressDelegate?.processingMedia(finished: false)
                item.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                    self?.progressDelegate?.processingMedia(finished: true)
                    if let image = object as? UIImage, let self = self {
                        self.latestPickedImageInfos = [compressImage(image, saveMemory: self.type == .shareExtension)]
                        let messages = self.confirmSendPhoto(friends: friends, emojiType: emojiType, messageType: .photo)
                        completion?(messages)
                    }
                }
            } else if item.canLoadObject(ofClass: String.self) {
                let myName = self.manager?.myName
                _ = item.loadObject(ofClass: String.self) { str, error in
                    if let str = str {
                        if let canSendData = canSendData, !canSendData(str) {
                            return
                        }
                        for friend in friends {
                            let message = self.processMessageString(for: str, type: .text, friend: friend, imageURL: nil, videoURL: nil)
                            NotificationCenter.default.post(name: .uploadSuccess, object: myName, userInfo: ["message": message as Any])
                        }
                    }
                }
            }
        }
    }


    func compressAndSendVideo(_ fileURL: URL, friends: [Friend], completion: (([Message]) -> Void)? = nil) {
        self.progressDelegate?.processingMedia(finished: false)
        let dir = createDir(name: videoDir)
        let uuid = UUID().uuidString
        let newURL = dir.appendingPathComponent(uuid).appendingPathExtension("mov")
        LivePhotoGenerator().compressVideo(withInputURL: fileURL, outputURL: newURL, quality: .quality540, compressType: .thirdParty) {
            self.pickedVideos = (newURL, self.resolutionForLocalVideo(url: newURL) ?? .zero)
            let messages = self.sendVideo(friends: friends)
            completion?(messages)
        }
    }

    private func resolutionForLocalVideo(url: URL) -> CGSize? {
        guard let track = AVURLAsset(url: url).tracks(withMediaType: AVMediaType.video).first else { return nil }
        let size = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(size.width), height: abs(size.height))
    }
    
    static func isMac() -> Bool {
        if #available(iOS 14, *), ProcessInfo.processInfo.isiOSAppOnMac {
            return true
        }
        if #available(iOS 13.0, *) {
            return ProcessInfo.processInfo.isMacCatalystApp
        } else {
            return false
        }
    }


}
