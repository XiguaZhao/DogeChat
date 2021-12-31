//
//  DogeChatTabBarController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/30.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatUniversal


class DogeChatTabBarController: UITabBarController, UITabBarControllerDelegate {

    var miniPlayerView: MiniPlayerView!
    
    var doubleTapGes: UITapGestureRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tabBar.layer.masksToBounds = true
        self.delegate = self
        setupMiniPlayer()
        NotificationCenter.default.addObserver(self, selector: #selector(nowPlayingTrackChangedNoti(_:)), name: .nowPlayingTrackChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(nowPlayingListChangedNoti(_:)), name: .nowPlayingListChanged, object: nil)
        if let first = getFirstButton() {
            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
            doubleTap.numberOfTapsRequired = 2
            first.addGestureRecognizer(doubleTap)
            self.doubleTapGes = doubleTap
        }
    }
    
    @objc func nowPlayingListChangedNoti(_ noti: Notification) {
        let newList = noti.object as! [Track]
        miniPlayerView.tracks = newList
        miniPlayerView.reloadData()
    }
    
    @objc func nowPlayingTrackChangedNoti(_ noti: Notification) {
        miniPlayerView.reloadData()
        miniPlayerView.changePlayPauseButton()
    }
    
    func setupMiniPlayer() {
        let miniPlayer = MiniPlayerView()
        miniPlayerView = miniPlayer
        miniPlayer.isHidden = true
//        self.view.insertSubview(miniPlayer, belowSubview: self.tabBar)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if self.tabBar.isHidden {
        } else {
            miniPlayerView?.frame = CGRect(x: 0, y: view.bounds.height - tabBar.bounds.height - MiniPlayerView.height, width: view.bounds.width, height: MiniPlayerView.height)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        miniPlayerView.reloadData(justScroll: true)
    }

    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        self.doubleTapGes.isEnabled = tabBarController.selectedIndex == 0
        if PlayerManager.shared.nowPlayingTrack != nil {
            miniPlayerView.isHidden = false
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @objc func doubleTap(_ ges: UIGestureRecognizer) {
        NotificationCenter.default.post(name: NSNotification.Name("doubleTapBadge"), object: nil)
    }
    
    func getAllButton() -> [UIView] {
        let tabBar = self.tabBar
        var res: [UIView] = []
        if let className = NSClassFromString("UITabBarButton") {
            for subview in tabBar.subviews {
                if subview.isKind(of: className) {
                    res.append(subview)
                }
            }
        }
        return res.sorted(by: { $0.frame.minX < $1.frame.minX })
    }
    
    func getFirstButton() -> UIView? {
        return getAllButton().first
    }
    
    func getBadge() -> UIView? {
        if let firstButton = getFirstButton(), let badgeClass = NSClassFromString("_UIBadgeView") {
            for subview in firstButton.subviews {
                if subview.isKind(of: badgeClass) {
                    return subview
                }
            }
        }
        return nil
    }
}
