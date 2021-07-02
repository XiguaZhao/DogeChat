//
//  SplitViewControllerDelegate.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/7/1.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class SplitViewControllerDelegate: UISplitViewControllerDelegate {
    
    
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        if let nav = AppDelegate.shared.tabBarController.selectedViewController as? UINavigationController {
            if let vc = (secondaryViewController as? UINavigationController)?.viewControllers.last {
                nav.pushViewController(vc, animated: false)
            }
        }
        return true
    }
        
    func splitViewControllerDidExpand(_ svc: UISplitViewController) {
        if let nav = AppDelegate.shared.tabBarController.selectedViewController as? UINavigationController {
            if let pop = nav.popToRootViewController(animated: false)?.first {
                let newNav = DogeChatNavigationController(rootViewController: pop)
                svc.showDetailViewController(newNav, sender: nil)
                if let chatVC = pop as? ChatRoomViewController {
                    chatVC.collectionView.reloadData()
                    AppDelegate.shared.navigationController = newNav
                }
            }
        }
    }
}
