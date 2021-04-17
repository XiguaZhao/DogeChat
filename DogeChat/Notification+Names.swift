//
//  Notification+Names.swift
//  DogeChat
//
//  Created by 赵锡光 on 2020/1/15.
//  Copyright © 2020 Luke Parham. All rights reserved.
//

import Foundation

extension Notification.Name {
    static let shouldResignFirstResponder = Notification.Name("shouldResignFirstResponder")
    static let receiveNewMessage = Notification.Name("receiveNewMessage")
    static let sendSuccess = Notification.Name("sendSuccseeNotification")
    static let uploadSuccess = Notification.Name("uploadSuccessNotification")
    static let confirmSendPhoto = Notification.Name("confirmSendPhotoNotification")
    static let emojiButtonTapped = Notification.Name("emojiButtonTapped")
    static let emojiInfoChanged = Notification.Name("emojiInfoChanged")
    static let receiveHistoryMessages = Notification.Name("receiveHistoryMessages")
}
