//
//  UINavigationController+SplitVC.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/12/5.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

extension UINavigationController {
    
    func setViewControllersForSplitVC(vcs: [UIViewController], firstAnimated: Bool = false, secondAnimated: Bool = false, animatedIfCollapsed: Bool = true) {
        if let splitVC = self.splitViewController, !splitVC.isCollapsed {
            var vcs = vcs
            self.setViewControllers([vcs.removeFirst()], animated: firstAnimated)
            let nav = DogeChatNavigationController()
            nav.setViewControllers(vcs, animated: secondAnimated)
            splitVC.showDetailViewController(nav, sender: nil)
        } else {
            self.setViewControllers(vcs, animated: animatedIfCollapsed)
        }
    }
    
}
