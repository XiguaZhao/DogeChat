//
//  DogeChatViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/26.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class DogeChatViewController: UIViewController {
    
    var blurView: UIImageView!
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if self is ContactsTableViewController || self is PlayListViewController {
            additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: 60, right: 0)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(forceDarkMode(noti:)), name: .immersive, object: nil)
        toggleBlurView(force: AppDelegate.shared.immersive)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if let previous = previousTraitCollection, previous.userInterfaceStyle != UIScreen.main.traitCollection.userInterfaceStyle {
            NotificationCenter.default.post(name: .immersive, object: AppDelegate.shared.immersive)
        }
        AppDelegate.shared.lastUserInterfaceStyle = UIScreen.main.traitCollection.userInterfaceStyle
    }
    
    func recoverBackgroundColor() {
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            self.view.backgroundColor = .white
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func toggleBlurView(force: Bool) {
        if force {
            var tableView: UITableView?
            var needAnimation = true
            if let playListVC = self as? PlayListViewController  {
                tableView = playListVC.tableView
                if playListVC.type == .share {
                    needAnimation = false
                }
            } else if let selectPlayListVC = self as? PlayListsSelectVC {
                tableView = selectPlayListVC.tableView
                needAnimation = false
            } else if let settingVC = self as? SettingViewController {
                tableView = settingVC.tableView
            } else if let searchVC = self as? SearchMusicViewController {
                needAnimation = false
                searchVC.updateBgColor()
            } else if self is ChatRoomViewController {
                needAnimation = false
            } else if let contactVC = self as? ContactsTableViewController {
                tableView = contactVC.tableView
            }
            if let tableView = tableView {
                makeBlurViewForViewController(self, blurView: &blurView, needAnimation: needAnimation, addToThisView: tableView)
            } else {
                makeBlurViewForViewController(self, blurView: &blurView, needAnimation: needAnimation)
            }
        } else {
            recoverVC(self, blurView: &blurView)
            if let searchVC = self as? SearchMusicViewController {
                searchVC.updateBgColor()
            }
        }
    }
    
    @objc func forceDarkMode(noti: Notification) {
        let force = noti.object as! Bool
        DispatchQueue.main.async {
            self.toggleBlurView(force: force)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
    }

}
