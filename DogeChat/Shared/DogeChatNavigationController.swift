//
//  DogeChatNavigationController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/27.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class DogeChatNavigationController: UINavigationController {

    var blurView: UIImageView!
    
    var username = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        makeBlurViewForViewController(self, blurView: &blurView)
        NotificationCenter.default.addObserver(self, selector: #selector(forceDarkMode(noti:)), name: .immersive, object: nil)
    }
    
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: true)
    }
    
    override func popViewController(animated: Bool) -> UIViewController? {
        let popped = super.popViewController(animated: animated)
        return popped
    }
    
    @objc func forceDarkMode(noti: Notification) {
        let force = noti.object as! Bool
        if force {
            makeBlurViewForViewController(self, blurView: &blurView, username: username)
        } else {
            recoverVC(self, blurView: &blurView)
        }
    }

}
