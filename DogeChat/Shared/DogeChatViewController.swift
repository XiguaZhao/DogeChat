//
//  DogeChatViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/26.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class DogeChatViewController: UIViewController, UIPopoverPresentationControllerDelegate {
    
    var blurView: UIImageView!
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        NotificationCenter.default.addObserver(self, selector: #selector(immersive(noti:)), name: .immersive, object: nil)
        toggleBlurView(force: AppDelegate.shared.immersive, needAnimation: false)
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
    
    func toggleBlurView(force: Bool, needAnimation: Bool) {
        if force {
            var tableView: UITableView?
            if let playListVC = self as? PlayListViewController  {
                tableView = playListVC.tableView
            } else if let selectPlayListVC = self as? PlayListsSelectVC {
                tableView = selectPlayListVC.tableView
            } else if let settingVC = self as? SettingViewController {
                tableView = settingVC.tableView
            } else if let searchVC = self as? SearchMusicViewController {
                tableView = searchVC.tableView
            } else if let chatVC = self as? ChatRoomViewController {
                tableView = chatVC.tableView
            } else if let contactVC = self as? ContactsTableViewController {
                tableView = contactVC.tableView
            } else if let selectContact = self as? SelectContactsViewController {
                tableView = selectContact.tableView
            } else {
                if #available(iOS 13.0, *) {
                    if let historyVC = self as? HistoryVC {
                        tableView = historyVC.tableView
                    }
                } 
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
    
    @objc func immersive(noti: Notification) {
        let force = noti.object as! Bool
        DispatchQueue.main.async {
            self.toggleBlurView(force: force, needAnimation: true)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
    }

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }

}
