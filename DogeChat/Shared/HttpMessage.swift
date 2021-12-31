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

class HttpMessage {
    
    let httpManager = HttpRequestsManager()
    let messageManager = MessageManager()
    
    init() {
        httpManager.messageManager = messageManager
        messageManager.httpRequestsManager = httpManager
        messageManager.encrypt = EncryptMessage()
    }
    
    func getKey(completion: @escaping((Bool) -> Void)) {
        httpManager.getPublicKey { key in
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
            httpManager.getContacts { contacts, error in
                if !contacts.isEmpty, error == nil {
                    completion(contacts)
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    func sendText(_ text: String, to friend: String, completion: @escaping((Bool, Friend?) -> Void)) {
        login { [weak self] loginSuccess in
            if loginSuccess {
                self?.getContacts { [weak self] friends in
                    if let friends = friends {
                        self?.getKey { [weak self] keySuccess in
                            if keySuccess {
                                guard let self = self else { return }
                                if let friend = friends.first(where: { $0.nickName == friend || $0.username == friend }) {
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

