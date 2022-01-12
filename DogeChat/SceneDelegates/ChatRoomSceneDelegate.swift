//
//  ChatRoomSceneDelegate.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/12/4.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatNetwork

@available(iOS 13.0, *)
class ChatRoomSceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    weak var chatRoomVC: ChatRoomViewController!
    
    var username = ""
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        (scene as? UIWindowScene)?.sizeRestrictions?.maximumSize = CGSize(width: 500, height: .max)
        if let nav = window?.rootViewController as? UINavigationController, let userInfo = connectionOptions.userActivities.first?.userInfo {
            if let friendID = userInfo["friendID"] as? String,
               let username = userInfo["username"] as? String,
               let manager = WebSocketManager.usersToSocketManager[username],
               let friend = manager.friends.first(where:  { $0.userID == friendID }){
                let chatRoom = ChatRoomViewController()
                self.chatRoomVC = chatRoom
                self.username = username
                chatRoom.username = username
                chatRoom.sceneType = .single
                chatRoom.friend = friend
                nav.setViewControllers([chatRoomVC], animated: false)
            }
        }
#if TARGET_OS_UIKITFORMAC || targetEnvironment(macCatalyst)
        if let titleBar = window?.windowScene?.titlebar {
            titleBar.titleVisibility = .hidden
            titleBar.toolbar = nil
        }
#endif
    }
    
}
