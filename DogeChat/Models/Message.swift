/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import Foundation

enum MessageType: String{
    case text
    case join
    case image
    case video
}

enum SendStatus {
    case success
    case fail
}

class Message: NSObject {
    var message: String
    let senderUsername: String
    let messageSender: MessageSender
    var messageType: MessageType
    let date: String
    let option: MessageOption
    var id: Int
    var receiver = ""
    var uuid: String
    var imageURL: String?
    var videoURL: String?
    
    var sendStatus: SendStatus = .success
    
    init(message: String, imageURL: String?=nil, videoURL: String?=nil, messageSender: MessageSender, receiver: String = "", uuid: String = UUID().uuidString, sender: String, messageType: MessageType, option: MessageOption = .toOne, id: Int = 0, date: String = "", sendStatus: SendStatus = .success) {
        self.message = message.withoutWhitespace()
        self.messageSender = messageSender
        self.senderUsername = sender
        self.messageType = messageType
        self.option = option
        self.id = id
        self.date = date
        self.sendStatus = sendStatus
        self.receiver = receiver
        self.imageURL = imageURL
        self.videoURL = videoURL
        self.uuid = uuid
    }
}
