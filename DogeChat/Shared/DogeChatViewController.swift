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

func makeBlurViewForViewController(_ vc: UIViewController, blurView: inout UIImageView!, needAnimation: Bool = true, addToThisView: UIView? = nil) {
    var targetImage: UIImage?
    if UserDefaults.standard.bool(forKey: "immersive") && PlayerManager.shared.nowAlbumImage != nil && PlayerManager.shared.isPlaying {
        targetImage = PlayerManager.shared.nowAlbumImage
    } else if fileURLAt(dirName: "customBlur", fileName: userID) != nil && PlayerManager.shared.customImage != nil {
        targetImage = PlayerManager.shared.customImage
    }
    guard let targetImage = targetImage else { return }
    if #available(iOS 13.0, *) {
        let interfaceStyle: UIUserInterfaceStyle
        if UserDefaults.standard.bool(forKey: "forceDarkMode") {
            interfaceStyle = .dark
        } else {
            interfaceStyle = .unspecified
        }
        AppDelegate.shared.window?.overrideUserInterfaceStyle = interfaceStyle
        vc.navigationController?.overrideUserInterfaceStyle = interfaceStyle
        vc.splitViewController?.overrideUserInterfaceStyle = interfaceStyle
        vc.tabBarController?.overrideUserInterfaceStyle = interfaceStyle
        vc.overrideUserInterfaceStyle = interfaceStyle

        vc.view.backgroundColor = .clear
    }
    vc.view.backgroundColor = .clear
    var style: UIBlurEffect.Style
    if UserDefaults.standard.bool(forKey: "forceDarkMode") {
        style = .dark
    } else {
        style = .regular
    }
    if style == .regular && UIScreen.main.traitCollection.userInterfaceStyle == .light {
        if #available(iOS 13.0, *) {
            style = .extraLight
        }
    }
    if blurView == nil {
        blurView = UIImageView(image: targetImage)
        PlayerManager.shared.blurView = blurView
        blurView.alpha = 0
        blurView.isHidden = false
        blurView.contentMode = .scaleAspectFill
        let blurEffect = UIBlurEffect(style: style)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurView.addSubview(blurEffectView)
        blurEffectView.mas_updateConstraints { make in
            make?.edges.equalTo()(blurView)
        }
        blurView.layer.masksToBounds = true
        let view = vc.view
        if let askedView = addToThisView as? UITableView {
            askedView.backgroundView = blurView
            blurView.frame = askedView.frame
        } else {
            if let view = view {
                view.addSubview(blurView)
                view.sendSubviewToBack(blurView)
                blurView.mas_updateConstraints { [weak view] make in
                    make?.edges.equalTo()(view)
                }
            }
        }
        if needAnimation {
            UIView.animate(withDuration: 0.5) { [weak blurView] in
                blurView?.alpha = 1
            }
        } else {
            blurView.alpha = 1
        }
    } else {
        blurView.isHidden = false
        for view in blurView.subviews {
            if let blurEffectView = view as? UIVisualEffectView {
                blurEffectView.effect = UIBlurEffect(style: style)
                break
            }
        }
        UIView.animate(withDuration: 0.5) { [weak blurView] in
            blurView?.alpha = 0.5
        } completion: { [weak blurView] _ in
            blurView?.image = targetImage
            UIView.animate(withDuration: 0.5) { [weak blurView] in
                blurView?.alpha = 1
            }
        }
    }
}

func recoverVC(_ vc: UIViewController, blurView: inout UIImageView!) {
    if #available(iOS 13.0, *) {
        vc.view.backgroundColor = .systemBackground
        AppDelegate.shared.window?.overrideUserInterfaceStyle = .unspecified
        vc.navigationController?.overrideUserInterfaceStyle = .unspecified
        vc.splitViewController?.overrideUserInterfaceStyle = .unspecified
        vc.tabBarController?.overrideUserInterfaceStyle = .unspecified
        vc.overrideUserInterfaceStyle = .unspecified
        vc.view.backgroundColor = .systemBackground
    }
    UIView.animate(withDuration: 0.5) { [weak blurView] in
        blurView?.alpha = 0
    } completion: { [weak blurView] _ in
        blurView?.isHidden = true
    }
}
