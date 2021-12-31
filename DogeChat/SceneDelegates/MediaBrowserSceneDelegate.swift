//
//  MediaBrowserSceneDelegate.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/12/22.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation
import UIKit

class MediaBrowserSceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
        
    var mediaPaths = [String]()
    
    weak var nav: UINavigationController! {
        window?.rootViewController as? UINavigationController
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let userInfo = connectionOptions.userActivities.first?.userInfo, let nav = self.nav {
            var vc: UIViewController?
            if let paths = userInfo["paths"] as? [String] {
                let mediaVC = MediaBrowserViewController()
                mediaVC.imagePaths = paths
                if let index = userInfo["index"] as? Int {
                    mediaVC.targetIndex = index
                }
                vc = mediaVC
            } else if let url = userInfo["url"] as? String {
                let webVC = WebViewController()
                webVC.apply(url: url)
                vc = webVC
            }
            if let vc = vc {
                nav.setViewControllers([vc], animated: false)
            }
        }
        
        #if targetEnvironment(macCatalyst)
        if let titleBar = window?.windowScene?.titlebar {
            titleBar.titleVisibility = .hidden
            titleBar.toolbar = nil
        }
        #endif
    }
    
}
