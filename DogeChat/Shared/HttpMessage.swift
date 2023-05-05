//
//  HttpMessage.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/12/12.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation
import RSAiOSWatchOS
import DogeChatUniversal
import DogeChatCommonDefines

class HttpMessage {
    
    let httpManager = HttpRequestsManager()
    let messageManager = MessageManager()
    
    var serverKey: String?
    
    init() {
        httpManager.messageManager = messageManager
        messageManager.httpRequestsManager = httpManager
        messageManager.encrypt = EncryptMessage()
    }
    
    func getKey(completion: @escaping((Bool) -> Void)) {
        if serverKey != nil {
            completion(true)
            return
        }
        httpManager.getPublicKey { key in
            self.serverKey = key
            completion(key != nil)
        }
    }
    
    func login(completion: @escaping((Bool) -> Void)) {
        if let (username, password) = getUsernameAndPassword() {
            httpManager.login(username: username, password: password, email: nil, token: nil) { res, _ in
                completion(res)
            }
        } else {
            completion(false)
        }
    }
    
    func getContacts(completion: @escaping(([Friend]?) -> Void)) {
        if !httpManager.friends.isEmpty {
            completion(httpManager.friends)
        } else {
            httpManager.getContacts(force: false) { contacts, error in
                if !contacts.isEmpty, error == nil {
                    completion(contacts)
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    func sendMessage(_ message: Message, completion: @escaping((Bool) -> Void)) {
        login { [weak self] loginSuccess in
            if loginSuccess {
                self?.getContacts { [weak self] friends in
                    self?.getKey { [weak self] keySuccess in
                        if keySuccess {
                            guard let self = self else { return }
                            self.httpManager.sendMessage(message) { success in
                                if success {
                                    completion(true)
                                } else {
                                    completion(false)
                                }
                            }
                        } else {
                            completion(false)
                        }
                    }
                }
            } else {
                completion(false)
            }
        }
    }
    
    func sendText(_ text: String, to friend: String, userID: String? = nil, type: MessageType = .text, completion: @escaping((Bool, Friend?) -> Void)) {
        login { [weak self] loginSuccess in
            if loginSuccess {
                self?.getContacts { [weak self] friends in
                    if let friends = friends {
                        self?.getKey { [weak self] keySuccess in
                            if keySuccess {
                                guard let self = self else { return }
                                var targetFriend: Friend?
                                if let userID = userID {
                                    targetFriend = friends.first(where: { $0.userID == userID })
                                } else {
                                    targetFriend = friends.first(where: { $0.nickName == friend || $0.username == friend })
                                }
                                if let friend = targetFriend {
                                    let message = Message(message: text, friend: friend, messageSender: .ourself, receiver: friend.username, receiverUserID: friend.userID, sender: self.httpManager.myName, senderUserID: self.httpManager.myId, messageType: .text)
                                    self.httpManager.sendMessage(message) { success in
                                        if success {
                                            completion(true, friend)
                                        } else {
                                            completion(false, nil)
                                        }
                                    }
                                } else {
                                    completion(false, nil)
                                }
                            } else {
                                completion(false, nil)
                            }
                        }
                    } else {
                        completion(false, nil)
                    }
                }
            } else {
                completion(false, nil)
            }
        }
    }
    
}

