//
//  DogeChatViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/26.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatUniversal
import DogeChatNetwork
import DogeChatCommonDefines

protocol DogeChatVCTableDataSource: AnyObject {
    var tableView: DogeChatTableView { get set }
}

class DogeChatViewController: UIViewController, UIPopoverPresentationControllerDelegate {
    
    var blurView: UIImageView!
    var username = ""
        
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            self.view.backgroundColor = .white
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            NotificationCenter.default.addObserver(self, selector: #selector(self.immersive(noti:)), name: .immersive, object: nil)
        }
        toggleBlurView(needBlur: AppDelegate.shared.immersive, needAnimation: false)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if let previous = previousTraitCollection, previous.userInterfaceStyle != self.traitCollection.userInterfaceStyle {
            NotificationCenter.default.post(name: .immersive, object: AppDelegate.shared.immersive)
        }
    }
        
    func recoverBackgroundColor() {
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesBegan(presses, with: event)
        if let key = presses.first?.key {
            let keyCode = key.keyCode
            if keyCode == .keyboardEscape {
                if self.presentingViewController != nil {
                    self.dismiss(animated: true, completion: nil)
                } else {
                    self.navigationController?.popViewController(animated: true)
                }
            }
        }
    }
    
    func toggleBlurView(needBlur: Bool, needAnimation: Bool) {
        if self.username.isEmpty, let myName = (self.splitViewController as? DogeChatSplitViewController)?.findContactVC()?.username {
            self.username = myName
        }
        if needBlur {
            var tableView: UITableView?
            if let tableViewDataSource = self as? DogeChatVCTableDataSource {
                tableView = tableViewDataSource.tableView
            }
            if let tableView = tableView {
                makeBlurViewForViewController(self, blurView: &blurView, needAnimation: needAnimation, addToThisView: tableView, username: self.username)
            } else {
                makeBlurViewForViewController(self, blurView: &blurView, needAnimation: needAnimation, username: self.username)
            }
        } else {
            recoverVC(self, blurView: &blurView)
        }
    }
    
    @objc func immersive(noti: Notification) {
        let force = noti.object as! Bool
        DispatchQueue.main.async {
            self.toggleBlurView(needBlur: force, needAnimation: true)
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

func makeBlurViewForViewController(_ vc: UIViewController, blurView: inout UIImageView!, needAnimation: Bool = true, addToThisView: UIView? = nil, username: String? = nil) {
    var username = username
    if #available(iOS 13.0, *) {
        if (username == nil || (username ?? "").isEmpty) && SceneDelegate.usernameToDelegate.count == 1 {
            username = SceneDelegate.usernameToDelegate.keys.first
        }
    }
    var targetImage: UIImage?
    if UserDefaults.standard.bool(forKey: "immersive") && PlayerManager.shared.nowAlbumImage != nil && PlayerManager.shared.isPlaying {
        targetImage = PlayerManager.shared.nowAlbumImage
    } else if let username = username, let userID = userIDFor(username: username), let url = fileURLAt(dirName: "customBlur", fileName: userID) {
        targetImage = UIImage(data: try! Data(contentsOf: url))
    } else if fileURLAt(dirName: "customBlur", fileName: userID) != nil && PlayerManager.shared.customImage != nil {
        targetImage = PlayerManager.shared.customImage
    }
    guard let targetImage = targetImage else {
        return
    }
    let interfaceStyle: UIUserInterfaceStyle
    if UserDefaults.standard.bool(forKey: "forceDarkMode") {
        if #available(iOS 13, *) {
            interfaceStyle = .dark
        } else {
            interfaceStyle = .light
        }
    } else {
        interfaceStyle = .unspecified
    }
    if #available(iOS 13.0, *) {
        vc.navigationController?.overrideUserInterfaceStyle = interfaceStyle
        vc.splitViewController?.overrideUserInterfaceStyle = interfaceStyle
        vc.tabBarController?.overrideUserInterfaceStyle = interfaceStyle
        vc.overrideUserInterfaceStyle = interfaceStyle
        SceneDelegate.usernameToDelegate[username ?? ""]?.window?.overrideUserInterfaceStyle = interfaceStyle
    } else {
        // Fallback on earlier versions
    }
    vc.view.backgroundColor = .clear
    vc.view.backgroundColor = .clear
    var style: UIBlurEffect.Style = .regular
    if UserDefaults.standard.bool(forKey: "forceDarkMode") {
        if #available(iOS 13, *) {
            style = .dark
        } else {
            style = .extraLight
        }
    } else {
        style = .regular
    }
    if style == .regular && UIScreen.main.traitCollection.userInterfaceStyle == .light {
        style = .extraLight
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
        vc.navigationController?.overrideUserInterfaceStyle = .unspecified
        vc.splitViewController?.overrideUserInterfaceStyle = .unspecified
        vc.tabBarController?.overrideUserInterfaceStyle = .unspecified
        vc.overrideUserInterfaceStyle = .unspecified
        vc.splitViewController?.view.backgroundColor = .systemBackground
        vc.view.window?.overrideUserInterfaceStyle = .unspecified
    } else {
        vc.view.backgroundColor = .white
    }
    UIView.animate(withDuration: 0.5) { [weak blurView] in
        blurView?.alpha = 0
    } completion: { [weak blurView] _ in
        blurView?.isHidden = true
    }
}
