//
//  SplitViewControllerDelegate.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/7/1.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit

class SplitViewControllerDelegate: UISplitViewControllerDelegate {
    
    weak var splitVC: UISplitViewController?
    
    var tabBarController: UITabBarController? {
        if #available(iOS 13.0, *) {
            return (self.splitVC?.view.window?.windowScene?.delegate as? SceneDelegate)?.tabbarController
        } else {
            return AppDelegate.shared.tabBarController
        }
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        if let nav = tabBarController?.selectedViewController as? UINavigationController {
            if let vc = (secondaryViewController as? UINavigationController)?.viewControllers.last {
                nav.pushViewController(vc, animated: false)
            }
        }
        return true
    }
        
    func splitViewControllerDidExpand(_ svc: UISplitViewController) {
        if let nav = tabBarController?.selectedViewController as? UINavigationController {
            if let pop = nav.popToRootViewController(animated: false)?.first {
                let newNav = DogeChatNavigationController(rootViewController: pop)
                svc.showDetailViewController(newNav, sender: nil)
            }
        }
    }
        
}
