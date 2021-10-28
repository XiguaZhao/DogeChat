//
//  DogeChatTabBarController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/30.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatUniversal

var miniPlayerView: MiniPlayerView!

class DogeChatTabBarController: UITabBarController, UITabBarControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.delegate = self
        setupMiniPlayer()
        NotificationCenter.default.addObserver(self, selector: #selector(nowPlayingTrackChangedNoti(_:)), name: .nowPlayingTrackChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(nowPlayingListChangedNoti(_:)), name: .nowPlayingListChanged, object: nil)
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
        if PlayerManager.shared.nowPlayingTrack != nil {
            miniPlayerView.isHidden = false
        }
    }
}
