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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(forceDarkMode(noti:)), name: .immersive, object: nil)
    }
    
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        miniPlayerView.isHidden = true
        super.pushViewController(viewController, animated: true)
    }
    
    override func popViewController(animated: Bool) -> UIViewController? {
        let popped = super.popViewController(animated: animated)
//        if self.visibleViewController == self.viewControllers.first {
//            miniPlayerView.isHidden = false
//        }
        return popped
    }
    
    @objc func forceDarkMode(noti: Notification) {
        let force = noti.object as! Bool
        if force {
            makeBlurViewForViewController(self, blurView: &blurView)
        } else {
            recoverVC(self, blurView: &blurView)
        }
    }

}
