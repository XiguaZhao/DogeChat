//
//  ChatRoom.swift
//  DogeChat
//
//  Created by 赵锡光 on 2020/1/5.
//  Copyright © 2020 Luke Parham. All rights reserved.
//

import UIKit
import AVKit

protocol ChatRoomDelegate: class {
  func receive(message: Message)
}

class ChatRoom: NSObject {
  
  weak var delegate: ChatRoomDelegate?
  
  var inputStream: InputStream!
  var outputStream: OutputStream!
  
  var username = ""
  let maxReadLength = 4096
  
  
  func setupNetworkCommunication() {
    var readStream: Unmanaged<CFReadStream>?
    var writeStream: Unmanaged<CFWriteStream>?
    
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, "47.102.114.94" as CFString, 5060, &readStream, &writeStream)
    inputStream = readStream!.takeRetainedValue()
    outputStream = writeStream!.takeRetainedValue()
    
    inputStream.delegate = self
    
    inputStream.schedule(in: .current, forMode: RunLoop.Mode.common)
    outputStream.schedule(in: .current, forMode: RunLoop.Mode.common)
    
    inputStream.open()
    outputStream.open()
  }
  
  func joinChat(username: String) {
    let data = "\(username) has joined".data(using: .utf8)!
    self.username = username
    
    _ = data.withUnsafeBytes {
      guard let pointer = $0.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
        print("Error joining chat")
        return
      }
      outputStream.write(pointer, maxLength: data.count)
    }
  }
  
  func sendMessage(_ message: Message) {
    let data = "\(message.senderUsername):\(message.message)".data(using: .utf8)!
    _ = data.withUnsafeBytes {
      guard let pointer = $0.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
        print("Error send message")
        return
      }
      outputStream.write(pointer, maxLength: data.count)
    }
  }
  
  func stopChatSession() {
    inputStream.close()
    outputStream.close()
  }
  
  func testSpeech() {
    Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { (_) in
      print("------")
      guard let url = Bundle.main.url(forResource: "test", withExtension: "m4a") else { return }
      guard let data = try? Data(contentsOf: url) else { return }
      _ = data.withUnsafeBytes {
        guard let pointer = $0.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
        print(self.outputStream.write(pointer, maxLength: data.count))
      }
    }
  }
}

extension ChatRoom: StreamDelegate {
  func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
    switch eventCode {
    case .hasBytesAvailable:
      print("new message received")
      readAvailableBytes(stream: aStream as! InputStream)
    case .errorOccurred:
      print("error occurred")
    case .endEncountered:
      print("new message received")
      stopChatSession()
    case .hasSpaceAvailable:
      print("has space available")
    default:
      print("some other event...")
    }
  }
  
  private func readAvailableBytes(stream: InputStream) {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxReadLength)
    
    while stream.hasBytesAvailable {
      let numberOfBytesRead = inputStream.read(buffer, maxLength: maxReadLength)
      
      if numberOfBytesRead < 0, let error = stream.streamError {
        print(error)
        break
      }
//      print(String(bytesNoCopy: buffer, length: numberOfBytesRead, encoding: .utf8, freeWhenDone: true))
      
//      if let message = processedMessageString(buffer: buffer, length: numberOfBytesRead) {
//        print(message)
//      }
    }
  }
  
  private func processedMessageString(buffer: UnsafeMutablePointer<UInt8>, length: Int) -> Message? {
    guard let stringArray = String(bytesNoCopy: buffer, length: length, encoding: .utf8, freeWhenDone: true)?.components(separatedBy: ":"),
      let name = stringArray.first,
      let message = stringArray.last
      else {
        return nil
    }
    let messageSender: MessageSender = name == self.username ? .ourself : .someoneElse
    return Message(message: message, messageSender: messageSender, sender: name, messageType: .text)
  }
}
