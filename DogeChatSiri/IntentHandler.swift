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

class IntentHandler: INExtension, INSendMessageIntentHandling {
    
    var receiver: String?
    var text: String?
    let httpMessage = HttpMessage()
    
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

        if  let text = self.text,
           let receiver = self.receiver {
            httpMessage.sendText(text, to: receiver) { [weak self] success, friend in
                if success, let myAccountInfo = self?.httpMessage.httpManager.accountInfo, let friend = friend {
                    let userActivity = NSUserActivity(activityType: "INSendMessageIntent")
                    userActivity.title = "ChatRoom"
                    let modal = UserActivityModal(friendID: friend.userID, accountInfo: myAccountInfo)
                    if let data = try? JSONEncoder().encode(modal) {
                        userActivity.userInfo = ["data": data]
                    }
                    completion(INSendMessageIntentResponse(code: .success, userActivity: userActivity))
                } else {
                    completion(INSendMessageIntentResponse(code: .failure, userActivity: nil))
                }
            }
        } else {
            completion(INSendMessageIntentResponse(code: .failure, userActivity: nil))
        }
    }
        
    
}

