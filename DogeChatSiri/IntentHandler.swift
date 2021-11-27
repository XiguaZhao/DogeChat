//
//  IntentHandler.swift
//  DogeChatSiri
//
//  Created by 赵锡光 on 2021/11/20.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Intents
import DogeChatUniversal
import RSAiOSWatchOS

class IntentHandler: INExtension, INSendMessageIntentHandling, INSearchForMessagesIntentHandling, INSetMessageAttributeIntentHandling {
    
    var receiver: String?
    var text: String?
    let httpManager = HttpRequestsManager()
    let messageManager = MessageManager()
    
    override init() {
        super.init()
        httpManager.messageManager = messageManager
        messageManager.httpRequestsManager = httpManager
        messageManager.encrypt = EncryptMessage()
    }
    
    override func handler(for intent: INIntent) -> Any {
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.
        
        return self
    }
    
    // MARK: - INSendMessageIntentHandling
    
    // Implement resolution methods to provide additional information about your intent (optional).
    func resolveRecipients(for intent: INSendMessageIntent, with completion: @escaping ([INSendMessageRecipientResolutionResult]) -> Void) {
        if let recipient = intent.recipients?.first {
            self.receiver = recipient.displayName
            completion([INSendMessageRecipientResolutionResult.success(with: recipient)])
            // If no recipients were provided we'll need to prompt for a value.
        } else {
            completion([INSendMessageRecipientResolutionResult.needsValue()])
        }
    }
    
    func resolveContent(for intent: INSendMessageIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let text = intent.content, !text.isEmpty {
            self.text = text
            completion(INStringResolutionResult.success(with: text))
        } else {
            completion(INStringResolutionResult.needsValue())
        }
    }
    
    // Once resolution is completed, perform validation on the intent and provide confirmation (optional).
    
    func confirm(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        // Verify user is authenticated and your app is ready to send a message.
        
        let response = INSendMessageIntentResponse(code: .ready, userActivity: nil)
        completion(response)
    }
    
    // Handle the completed intent (required).
    
    func handle(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        // Implement your application logic to send a message here.
        if let username = UserDefaults(suiteName: "group.demo.zhaoxiguang")?.value(forKey: "sharedUsername") as? String,
           let password = UserDefaults(suiteName: "group.demo.zhaoxiguang")?.value(forKey: "sharedPassword") as? String,
           let text = self.text,
           let receiver = self.receiver {
            let httpManager = self.httpManager
            httpManager.login(username: username, password: password) { success in
                if success {
                    httpManager.getContacts { friends, error in
                        if error == nil {
                            httpManager.getPublicKey { pubKey in
                                if pubKey != nil {
                                    if let friend = httpManager.friends.first(where: { $0.nickName == receiver || $0.username == receiver }) {
                                        let message = Message(message: text, friend: friend, messageSender: .ourself, receiver: receiver, receiverUserID: friend.userID, sender: httpManager.myName, senderUserID: httpManager.myId, messageType: .text)
                                        httpManager.sendMessage(message) { success in
                                            if success {
                                                let userActivity = NSUserActivity(activityType: "INSendMessageIntent")
                                                userActivity.title = "ChatRoom"
                                                userActivity.userInfo = ["username": username,
                                                                         "password": password,
                                                                         "friendID": friend.userID]
                                                completion(INSendMessageIntentResponse(code: .success, userActivity: userActivity))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            completion(INSendMessageIntentResponse(code: .failure, userActivity: nil))
        }
    }
    
    // Implement handlers for each intent you wish to handle.  As an example for messages, you may wish to also handle searchForMessages and setMessageAttributes.
    
    // MARK: - INSearchForMessagesIntentHandling
    
    func handle(intent: INSearchForMessagesIntent, completion: @escaping (INSearchForMessagesIntentResponse) -> Void) {
        // Implement your application logic to find a message that matches the information in the intent.
        
        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSearchForMessagesIntent.self))
        let response = INSearchForMessagesIntentResponse(code: .success, userActivity: userActivity)
        // Initialize with found message's attributes
        response.messages = [INMessage(
            identifier: "identifier",
            content: "I am so excited about SiriKit!",
            dateSent: Date(),
            sender: INPerson(personHandle: INPersonHandle(value: "sarah@example.com", type: .emailAddress), nameComponents: nil, displayName: "Sarah", image: nil,  contactIdentifier: nil, customIdentifier: nil),
            recipients: [INPerson(personHandle: INPersonHandle(value: "+1-415-555-5555", type: .phoneNumber), nameComponents: nil, displayName: "John", image: nil,  contactIdentifier: nil, customIdentifier: nil)]
            )]
        completion(response)
    }
    
    // MARK: - INSetMessageAttributeIntentHandling
    
    func handle(intent: INSetMessageAttributeIntent, completion: @escaping (INSetMessageAttributeIntentResponse) -> Void) {
        // Implement your application logic to set the message attribute here.
                
    }
}

extension EncryptMessage: RSAEncryptProtocol {}
