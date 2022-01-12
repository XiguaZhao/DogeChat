//
//  ChatRoom+Draw.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/3.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import Foundation
import PencilKit
import DogeChatCommonDefines
import SwiftyJSON

@available(iOS 13.0, *)
extension ChatRoomViewController: PKViewChangeDelegate {
    func pkView(pkView: PKCanvasView, message: Message?, newStroke: Any) {
        guard #available(iOS 14.0, *), let newStroke = newStroke as? PKStroke else { return }
        print("add new stroke")
        guard let message = message else { return }
        guard message.needRealTimeDraw else { return }
        let data = PKDrawing(strokes: [newStroke]).dataRepresentation()
        let base64String = data.base64EncodedString()
        manager?.sendRealTimeDrawData(base64String, sender: username, receiver: friendName, uuid: message.uuid, senderID: message.senderUserID, receiverID: message.receiverUserID)
    }
    
    func pkView(pkView: PKCanvasView, message: Message?, deleteStrokesIndex: [Int]) {
        print("delete\(deleteStrokesIndex.count)")
        guard let message = message else { return }
        if message.needRealTimeDraw {
            let indexes = deleteStrokesIndex
            manager?.sendRealTimeDrawData(indexes, sender: username, receiver: friendName, uuid: message.uuid, senderID: message.senderUserID, receiverID: message.receiverUserID)
        }
    }
    
    func pkViewDidFinishDrawing(pkView: PKCanvasView, message: Message?) {
        if let manager = manager, let message = message {
            message.sendStatus = .fail
            let data = pkView.drawing.dataRepresentation()
            let fileName = UUID().uuidString
            let dir = createDir(name: drawDir)
            let originalURL = dir.appendingPathComponent(fileName)
            saveFileToDisk(dirName: drawDir, fileName: fileName, data: data)
            message.pkLocalURL = originalURL
            if #available(iOS 14.0, *) {
                guard !pkView.drawing.strokes.isEmpty else { return }
            }
            let drawData = pkView.drawing.dataRepresentation()
            let bounds = pkView.drawing.bounds
            let x = Int(bounds.origin.x)
            let y = Int(bounds.origin.y)
            let width = Int(bounds.size.width)
            let height = Int(bounds.size.height)
            message.drawBounds = bounds
            if let index = self.messages.firstIndex(where: { $0.uuid == message.uuid }) {
                tableView.reloadRows(at: [IndexPath(item: index, section: 0)], with: .none)
            }
            insertNewMessageCell([message], forceScrollBottom: true)
            manager.uploadData(drawData, path: "message/uploadImg", name: "upload", fileName: "+\(x)+\(y)+\(width)+\(height)", needCookie: true, contentType: "application/octet-stream", params: nil) { task, data in
                guard let data = data else { return }
                let json = JSON(data)
                guard json["status"].stringValue == "success" else {
                    print("上传失败")
                    return
                }
                let filePath = manager.messageManager.encrypt.decryptMessage(json["filePath"].stringValue)
                message.pkDataURL = filePath
                message.text = message.pkDataURL ?? ""
                manager.sendDrawMessage(message)
                DispatchQueue.global().async {
                    let newURL = dir.appendingPathComponent(filePath.components(separatedBy: "/").last!)
                    try? FileManager.default.moveItem(at: originalURL, to: newURL)
                }
            }
        }
    }
    
    func pkViewDidCancelDrawing(pkView: PKCanvasView, message: Message?) {
        if let message = message {
            if #available(iOS 14.0, *) {
                if (message.pkLocalURL == nil && message.pkDataURL == nil) {
                    revoke(message: message)
                } else {
                    manager?.commonWebSocket.sendWrappedMessage(message)
                }
            }
        }
    }
    
}

