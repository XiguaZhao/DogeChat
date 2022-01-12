//
//  ChatRoom+Location.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/12/23.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation
import DogeChatCommonDefines

extension ChatRoomViewController: LocationVCDelegate {
    
    func confirmSendLocation(latitude: Double, longitude: Double, name: String) {
        let para = ["latitude": latitude, "longitude": longitude, "name": name] as [String : Any]
        let jsonStr = makeJsonString(for: para)
        if let wrapMessage = processMessageString(for: jsonStr, type: .location, imageURL: nil, videoURL: nil) {
            insertNewMessageCell([wrapMessage])
            manager?.commonWebSocket.sendWrappedMessage(wrapMessage)
        }
    }
    
}
