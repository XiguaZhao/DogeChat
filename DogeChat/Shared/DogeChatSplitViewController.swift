//
//  DogeChatSplitViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/9/8.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import CoreGraphics

class DogeChatSplitViewController: UISplitViewController {
    

    let vcDelegate = SplitViewControllerDelegate()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = vcDelegate
        vcDelegate.splitVC = self
        self.preferredPrimaryColumnWidthFraction = 0.35
        self.preferredDisplayMode = .allVisible
        NotificationCenter.default.addObserver(self, selector: #selector(self.logout(note:)), name: .logout, object: nil)
    }
    
    @objc func logout(note: Notification) {
        if findContactVC()?.username == note.object as? String, !self.isCollapsed {
            self.showDetailViewController(DogeChatViewController(), sender: nil)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        UserDefaults.standard.set([size.width, size.height], forKey: "windowSize")
    }
    
    func findContactVC() -> ContactsTableViewController? {
        if let tabBarController = self.viewControllers.first as? UITabBarController {
            if let nav = tabBarController.viewControllers?.first as? UINavigationController {
                for vc in nav.viewControllers {
                    if let contactVC = vc as? ContactsTableViewController {
                        return contactVC
                    }
                }
            }
        }
        return nil
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        if view.safeAreaInsets != safeArea {
            safeArea = view.safeAreaInsets
        }
    }
    
    func findChatRoomVC() -> ChatRoomViewController? {
        var nav: UINavigationController?
        if self.isCollapsed {
            nav = self.findContactVC()?.navigationController
        } else {
            if self.viewControllers.count >= 2, let _nav = self.viewControllers[1] as? UINavigationController {
                nav = _nav
            }
        }
        if let nav = nav {
            for vc in nav.viewControllers {
                if let chatRoom = vc as? ChatRoomViewController {
                    return chatRoom
                }
            }
        }
        return nil

    }

}
